-module(node_jsonrpc_serv).

%%% external exports
-export([start_link/2]).

%%% internal exports
-export([node_handler/3]).

%%% include files
-include_lib("util/include/jsonrpc.hrl").
-include_lib("util/include/log.hrl").
-include_lib("util/include/shorthand.hrl").
-include_lib("node/include/node.hrl").
-include_lib("node/include/node_route.hrl").

%%% constants

%%% records

%%% types

%%%
%%% exported: start_link
%%%

-spec start_link(na(), supervisor:sup_ref()) -> {ok, pid()}.

start_link({IpAddress, Port}, NodeSup) ->
    %% I would prefer to use NodeServ instead of NodeSup as handler
    %% argument but asking for it here would mean a deadlock. I could
    %% add support for some sort of delayed prcoessing in tcp_serv.erl 
    %% but I will not.
    jsonrpc_serv:start_link(IpAddress, Port, [],
                            {?MODULE, node_handler, [NodeSup]}).

node_handler(<<"get-routing-entries">>, undefined, NodeSup) ->
    {ok, Res} = node_serv:get_routing_entries(node_serv(NodeSup)),
    {ok, [json_routing_entry(Re) || Re <- Res]};
node_handler(<<"get-nodes">>, undefined, NodeSup) ->
    {ok, Nodes} = node_serv:get_nodes(node_serv(NodeSup)),
    {ok, [json_node(Node) || Node <- Nodes]};
node_handler(<<"enable-recalc">>, undefined, NodeSup) ->
    ok = node_serv:enable_recalc(node_serv(NodeSup)),
    {ok, true};
node_handler(<<"disable-recalc">>, undefined, NodeSup) ->
    ok = node_serv:disable_recalc(node_serv(NodeSup)),
    {ok, true};
node_handler(<<"recalc">>, undefined, NodeSup) ->
    ok = node_serv:recalc(node_serv(NodeSup)),
    {ok, true};
node_handler(Method, Params, _NodeSup) ->
    ?error_log({invalid_request, Method, Params}),
    JsonError = #json_error{code = ?JSONRPC_INVALID_REQUEST},
    {error, JsonError}.

node_serv(NodeSup) ->
    case get(node_serv) of
        undefined ->
            {ok, NodeServ} = node_sup:lookup_child(NodeSup, node_serv),
            put(node_serv, NodeServ),
            NodeServ;
        NodeServ ->
            NodeServ
    end.

json_routing_entry(Re) ->
    [{<<"oa">>, Re#routing_entry.oa},
     %%{<<"na">>, encode_na(Re#routing_entry.na)},
     {<<"path-cost">>, Re#routing_entry.path_cost},
     {<<"flags">>, Re#routing_entry.flags}].

%%encode_na({IpAddress, Port}) ->
%%    ?l2b([net_tools:string_address(IpAddress), ":", ?i2l(Port)]).

json_node(Node) ->
    [{<<"public-key">>, Node#node.public_key},
     {<<"path-cost">>, Node#node.path_cost}].
