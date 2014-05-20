# 1 Architecture

The directory server (DS) has a SSL/JSON-RPC based server exporting a
number of methods to be used by overlay network nodes (NODEs) to join
and maintain their overlay network membership.

DS also starts a UDP based server which understands a number of
ingoing and outgoing messages from NODES. They are encrypted using
shared key generated with a call to the method *publish_node* in the
SSL/JSON-RPC API.

NODEs also have a UDP based server understanding a number of of
ingoing and outgoing messages also being encrypted using PKI.

All traffic being sent directly between two NODEs are 1KB in size and
are encrypted using a shared secret which has ben agreed upon by the
two NODEs using PKI.

## 1.1) The DS SSL/JSON-RPC server

The server is HTTPS based and exports a set of JSON-RPC[1] methods and
it listens on port 443 which **must** be available through the DS
firewall. All rpc methods are PKI-signed by the caller but rpc results
are not.

Its main purpose is to make it possible for NODEs to maintain its
overlay network membership, keep a healthy set of neighbour NODEs and
reserve overlay addresses (OAs) and domain name.

The following methods are made available, i.e. specified using *Erlang
type specifications* with opaque data types and success return values
only:

```erlang
-spec get_public_key() -> public_key().
-spec publish_node(node_id() | undefined, public_key()) -> {node_id(), ttl()}
-spec unpublish_node(node_id()) -> ok.
-spec get_random_nodes(node_id()) -> [{node_id(), public_key()}].
-spec reserve_oas(node_id(), [oa()]) -> ok.
-spec unreserve_oas(node_id(), [oa()]) -> ok.
-spec reserve_names(node_id(), [string()]) -> ok.
-spec unreserve_name(node_id(), [string()]) -> ok.
-spec still_published_nodes([node_id()]) -> [node_id()].
-spec reserved_oas(node_id()) -> [oa()].
-spec get_network_topology(node_id()) -> opaque().
```

 Note: reserved_oas/1 (to be used for debugging) and
 get_network_topology/1 (to be used to export the global network
 topology) are only available if the experimental api has been
 enabled.


id seqnr data (seqnr last bit is info about last packet)
512 udp packet size
keep up till X number of rearranged packets
max size of input packets








= 2 Use Cases

== 2.1 NODE joining overlay network

NODE A is joining the overlay network. NODE B is an old member.

```
NODE A                             DS                             NODE B
get_public_key <--ssl-------------->
publish_node <--ssl---------------->
punch_hole --udp------------------->
<-----------------udp-- hole_punched
punch_hole --udp------------------->
... (each ~20 seconds if needed)
get_random_nodes <--ssl------------>
negotiate_tunnel --udp------------->
                                    negotiate_tunnel --udp------------->
                                    <------------udp-- tunnel_negotiated
<------------udp-- tunnel_negotiated
<-------------------------------------------------------udp-- punch_hole
                                        (each ~20 seconds if needed) ...
punch_hole --udp------------------------------------------------------->
... (each ~20 seconds if needed)
share_secret --udp----------------------------------------------------->
<----------------------------------------------------udp-- secret_shared
cell --udp------------------------------------------------------------->
... (stream of 1024KB cells)
<-------------------------------------------------------------udp-- cell
                                            (stream of 1024KB cells) ...
```

NOTE: All messages sent diretctly between NODEs are 1KB in size

1) NODE calls get_public_key/0 in DS
   * The NODE will use the returned DS public_key() when it later
     calls the DS udp-cryptobox/jsonrpc server methods.

2) NODE calls publish_node/2 in DS
   * The node_id() input parameter is undefined the first time.
   * The returned node_id() is the NODE's unique identifier from now.
   * The NODE must call publish_node/2 again within ttl() hours or
     else the NODE will be deactivated in the DS state.
   * During a republish a NODE can update its public_key() and ip().
   * After X weeks the node_id() will be removed altogether from DS.
   * DS adds {node_id(), {ip(), public_key()}} to its ETS table,
     i.e. the ip() is the NODE's external ip-address.

3) NODE calls punch_hole/1 in DS
   * It does this until DS answers by calling hole_punched/1 in NODE.
   * DS now knows the external UDP port for NODE's udp-cryptobox/jsonrpc
     server, i.e. it updates the NODE's entry in its ETS table with
     {node_id(), {ip(), udp_port(), public_key()}.
   * From now on NODE must call keepalive/1 each ~minute to ensure
     that DS can reach NODE via its NAT device (the UDP port may
     change too if NODE restarts its udp-cryptobox/jsonrpc server).

4) NODE calls get_random_nodes/1 in DS
   * As a result it gets a list of with neighbouring nodes' node_id()
     and public_key().

5) NODE opens UDP sockets to be used as endpoints to encrypted tunnels
   to be setup for each NODE neighbour retrieved in (4). NODE then
   calls negotiate_with_neighbour/2 in DS for each neighbour NODE.
   * When DS reacts to such a call it at the same time gets to know the
     external source UDP port for the tunnel to be.
   * DS calls neighbour_is_negotiating/2 in the neighbour NODE and it opens a UDP socket

= 3 API

== 3.1 ssl/jsonrpc server

It has the following methods:

```erlang
-spec get_public_key() -> public_key().
-spec publish_node(node_id() | undefined, public_key()) -> {node_id(), ttl()}
-spec unpublish_node(node_id()) -> ok.
-spec get_random_nodes(node_id()) -> [{node_id(), public_key()}].
-spec reserve_oas(node_id(), [oa()]) -> ok.
-spec unreserve_oas(node_id(), [oa()]) -> ok.
-spec reserve_names(node_id(), [string()]) -> ok.
-spec unreserve_name(node_id(), [string()]) -> ok.
-spec still_published_nodes([node_id()]) -> [node_id()].
-spec reserved_oas(node_id()) -> [oa()].
-spec get_network_topology(node_id()) -> opaque().
```


DS udp-cryptobox/jsonrpc server
-------------------------------
It has the following methods:

-spec punch_hole(node_id()) -> none().
-spec negotiate_tunnel_ports(rpc_id(), node_id(), node_id()) -> udp_port().

All types above are opaque and the only the success return values are
specified.

All rpc calls and results are crypto-boxed.

The server listens on a UDP port which *must* be open in the DS
firewall.

Note: No "id" property is sent in the JSON-RPC requests, i.e. it is a
notification [http://www.jsonrpc.org/specification].

PART 2: UDP/Crypto-Box server on NODE
=====================================

It has the following methods:

-spec get_nodes() -> opaque().
-spec get_route_entries() -> opaque().

Note: get_nodes/0 and get_route_entries/0 are only available when the
experimental api is enabled. They are used by the experimental
get_network_topology/1 in DS.

All types above are opaque and the only the success return values are
specified.

All rpc calls and results are crypto-boxed.

The server listens on a port which can be closed in the NODE firewall.

Note: No "id" property is sent in the JSON-RPC requests, i.e. it is a
notification [http://www.jsonrpc.org/specification].


= References

[1] http://www.jsonrpc.org/specification