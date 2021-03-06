-module(node_tun_serv).

%%% external exports
-export([start_link/2, stop/1, stop/2]).

%%% system exports
-export([system_continue/3, system_terminate/4, system_code_change/4,
         system_get_state/1, system_replace_state/2]).

%%% internal exports
-export([init/3]).

%%% include files
-include_lib("node/include/node.hrl").
-include_lib("node/include/node_route.hrl").
-include_lib("util/include/config.hrl").
-include_lib("util/include/log.hrl").

%%% constants

%%% records

-record(state, {
          parent            :: pid(),
          node_db           :: node_db(),
          route_db          :: route_db(),
          node_recv_serv    :: pid(),
          tun_fd            :: tun_fd(),
          tun_pid           :: pid() | 'undefined',
          tun_mtu           :: non_neg_integer(),
          restart_tun       :: boolean(),
          %% anond.conf parameters
          my_na             :: na(),
          logging           :: boolean(),
          create_tun_device :: boolean(),
          my_oa             :: oa()}).

%%% types
-type tun_fd() :: integer() | 'undefined'. %% tunctl has no type specifications

%%%
%%% exported: start_link
%%%

-spec start_link(na(), supervisor:sup_ref()) -> {'ok', pid()}.

start_link(MyNa, NodeInstanceSup) ->
    Args = [self(), MyNa, NodeInstanceSup],
    Pid = proc_lib:spawn_link(?MODULE, init, Args),
    receive
	{Pid, started} ->
	    {ok, Pid}
    end.

%%%
%%% exported: stop
%%%

stop(Pid) ->
    stop(Pid, 15000).

-spec stop(pid(), timeout()) -> 'ok'.

stop(Pid, Timeout) ->
    serv:call(Pid, stop, Timeout).

%%%
%%% server loop
%%%

init(Parent, MyNa, NodeInstanceSup) ->
    process_flag(trap_exit, true),
    ok = config_json_serv:subscribe(),
    S = read_config(#state{parent = Parent, my_na = MyNa}),
    Parent ! {self(), started},
    %% Note: The supervisor will not be available until all its children
    %% have been started, i.e. calls to node_instance_sup:lookup_child/2
    %% must be delayed until now
    {ok, NodeRouteServ} =
        node_instance_sup:lookup_child(NodeInstanceSup, node_route_serv),
    {ok, NodeRecvServ} =
        node_instance_sup:lookup_child(NodeInstanceSup, node_recv_serv),
    {ok, NodeDb, RouteDb} = node_route_serv:handshake(NodeRouteServ, ?MODULE),
    ok = node_recv_serv:handshake(NodeRecvServ, {?MODULE, S#state.tun_fd}),
    {TunFd, TunPid} =
        manage_tun_device(S#state.tun_mtu, S#state.create_tun_device,
                          S#state.my_oa),
    ok = log_serv:toggle_logging(self(), S#state.logging),
    loop(S#state{node_db = NodeDb, route_db = RouteDb,
                 node_recv_serv = NodeRecvServ, tun_fd = TunFd,
                 tun_pid = TunPid}).

loop(#state{parent = Parent,
            node_db = NodeDb,
            route_db = RouteDb,
            node_recv_serv = NodeRecvServ,
            tun_fd = _TunFd,
            tun_pid = TunPid,
            tun_mtu = _TunMtu,
            restart_tun = _RestartTun,
            my_na = MyNa,
            logging = _Logging,
            create_tun_device = _CreateTunDevice,
            my_oa = MyOa} = S) ->
    receive
        config_updated ->
            ?daemon_log("~s starts to update its configuration",
                        [net_tools:string_address(MyNa)]),
            case read_config(S) of
                S ->
                    loop(S);
                UpdatedS ->
                    {UpdatedTunFd, UpdatedTunPid} =
                        manage_tun_device(
                          UpdatedS#state.tun_mtu,
                          UpdatedS#state.create_tun_device,
                          UpdatedS#state.my_oa, MyOa, TunPid,
                          UpdatedS#state.restart_tun),
                    ok = node_recv_serv:handshake(NodeRecvServ,
                                                  {?MODULE, UpdatedTunFd}),
                    loop(UpdatedS#state{tun_fd = UpdatedTunFd,
                                        tun_pid = UpdatedTunPid,
                                        restart_tun = false})
            end;
        %% ipv6 packet arrives on tun device
        {tuntap, TunPid,
         <<_:128, % skip leading 128 bits in ipv6 packet
           DestOa0:16, DestOa1:16, DestOa2:16, DestOa3:16,
           DestOa4:16, DestOa5:16, DestOa6:16, DestOa7:16,
           _/binary>> = Ipv6Packet} ->
            DestOa = {DestOa0, DestOa1, DestOa2, DestOa3,
                      DestOa4, DestOa5, DestOa6, DestOa7},
            send(DestOa, NodeDb, RouteDb, Ipv6Packet),
            loop(S);
        {tuntap_error, TunPid, Reason} ->
            ?daemon_log("Tun device error: ~s", [inet:format_error(Reason)]),
            loop(S);
	{From, stop} ->
	    From ! {self(), ok};
        {'EXIT', Parent, Reason} ->
            exit(Reason);
        %% tunctl is a bit broken
        {'EXIT', _, {{badmatch, {error, Reason}}, _}} ->
            ?daemon_log("Tun device error: ~s", [inet:format_error(Reason)]),
            loop(S#state{tun_fd = undefined, tun_pid = undefined});
        {system, From, Msg} ->
            sys:handle_system_msg(Msg, From, Parent, ?MODULE, [], S);
	UnknownMessage ->
	    ?error_log({unknown_message, UnknownMessage}),
	    loop(S)
    end.

system_continue(_Parent, _Debug, S) ->
    loop(S).

system_terminate(Reason, _Parent, _Debug, _S) ->
    exit(Reason).

system_code_change(S, _Module, _OldVsn, _Extra) ->
    {ok, S}.

system_get_state(S) ->
    {ok, S}.

system_replace_state(StateFun, S) ->
    NewS = StateFun(S),
    {ok, NewS, NewS}.

send(DestOa, NodeDb, RouteDb, Ipv6Packet) ->
    case node_route:lookup_node_send_serv(NodeDb, RouteDb, DestOa) of
        {ok, NodeSendServ} ->
            ok = node_send_serv:send(NodeSendServ,
                                     {?MODULE, DestOa, Ipv6Packet});
        {error, Reason} ->
            ?error_log(Reason),
            ok
    end.

%%%
%%% init
%%%

read_config(S) ->
    NodeInstancePath = [nodes, {'node-address', S#state.my_na}],
    try
        NodeInstance = ?config(NodeInstancePath),
        read_config(S, NodeInstance)
    catch
        throw:{unknown_config_parameter, NodeInstancePath} ->
            S
    end.

read_config(S, []) ->
    S;
read_config(S, [{'logging', Value}|Rest]) ->
    read_config(S#state{logging = Value}, Rest);
read_config(S, [{'create-tun-device', Value}|Rest]) ->
    read_config(S#state{create_tun_device = Value}, Rest);
read_config(S, [{'overlay-addresses', [Oa]}|Rest]) ->
    if
        S#state.my_oa == Oa ->
            read_config(S, Rest);
        true ->
            read_config(S#state{my_oa = Oa, restart_tun = true}, Rest)
    end;
read_config(_S, [{'overlay-addresses', _Oa}|_Rest]) ->
    throw(nyi);
%% Note: An ip packet created by node_send_serv.erl requires an 19+28
%% (47) bytes header. See node_send_serv.erl.
read_config(S, [{'max-cell-size', Value}|Rest]) ->
    TunMtu = Value-47,
    if
        S#state.tun_mtu == TunMtu ->
            read_config(S, Rest);
        true ->
            read_config(S#state{tun_mtu = TunMtu, restart_tun = true}, Rest)
    end;
read_config(S, [_|Rest]) ->
    read_config(S, Rest).

manage_tun_device(TunMtu, CreateTunDevice, MyOa) ->
    manage_tun_device(TunMtu, CreateTunDevice, MyOa, undefined, undefined,
                      false).

manage_tun_device(TunMtu, CreateTunDevice, MyOa, MyCurrentOa, CurrentTunTid,
                  RestartTun) ->
    case toggle_tun_device(TunMtu, CreateTunDevice, MyOa, MyCurrentOa,
                           CurrentTunTid, RestartTun) of
        undefined ->
            {undefined, undefined};
        TunTid ->
            {tuncer:getfd(TunTid), TunTid}
    end.

toggle_tun_device(TunMtu, true, MyOa, _MyCurrentOa, undefined, _RestartTun) ->
    create_tun_device(TunMtu, MyOa);
toggle_tun_device(TunMtu, true, MyOa, MyOa, CurrentTunTid, true)
  when CurrentTunTid /= undefined ->
    remove_tun_device(MyOa, CurrentTunTid),
    create_tun_device(TunMtu, MyOa);
toggle_tun_device(_TunMtu, true, MyOa, MyOa, CurrentTunTid, false)
  when CurrentTunTid /= undefined ->
    CurrentTunTid;
toggle_tun_device(TunMtu, true, MyOa, MyCurrentOa, CurrentTunTid,
                  _RestartTun) ->
    remove_tun_device(MyCurrentOa, CurrentTunTid),
    create_tun_device(TunMtu, MyOa);
toggle_tun_device(_TunMtu, false, _MyOa, _MyCurrentOa, undefined,
                  _RestartTun) ->
    undefined;
toggle_tun_device(_TunMtu, false, _MyOa, MyCurrentOa, CurrentTunTid,
                  _RestartTun) ->
    remove_tun_device(MyCurrentOa, CurrentTunTid).

create_tun_device(TunMtu, MyOa) ->
    case tuncer:create(<<"anond">>, [tun, no_pi, {active, true}]) of
        {ok, TunPid} ->
            case tuncer:up(TunPid, MyOa, 64, TunMtu) of
                ok ->
                    ?daemon_log("Created tun device with ip address ~s",
                                [net_tools:string_address(MyOa)]),
                    TunPid;
                {error, Reason} ->
                    tuncer:destroy(TunPid),
                    ?daemon_log("Could not add ip address ~s to tun device: ~s",
                                [net_tools:string_address(MyOa),
                                 inet:format_error(Reason)]),
                    undefined
            end;
        {error, Reason} ->
            ?daemon_log("Could not create tun device: ~s",
                        [inet:format_error(Reason)]),
            undefined
    end.

remove_tun_device(MyOa, TunPid) ->
    case tuncer:down(TunPid) of
        ok ->
            tuncer:destroy(TunPid),
            undefined;
        {error, Reason} ->
            ?daemon_log("Could not delete ip address ~s: ~s",
                        [net_tools:string_address(MyOa),
                         inet:format_error(Reason)]),
            tuncer:destroy(TunPid),
            undefined
    end.
