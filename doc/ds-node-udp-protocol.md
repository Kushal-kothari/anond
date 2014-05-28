# The DS-node UDP protocol

## 1) Overview

The DS-node UDP protocol is a bit oriented protocol where each
protocol message is an encrypted 74 bytes packet. It provides a number
of services aimed at the member nodes of an anond overlay network:

* Node registration
* Node keepalive handling towards DS
* Node-node tunnel establishment
* Network topology extraction (for debugging/experimentation)

The cells are encrypted using a Salsa20/20 cipher as described in [1],
i.e. each cell starts with a clear text node id (32 bits unsigned
integer) and a clear text client nonce (24 bytes) as described in
[2]. The remaining 48 bytes is the actual payload of the different
cell types. Protocol messages can be initiated by
the DS or the nodes as seen in this document.

The encryption is performed using a unique secret key which is shared
between each node and the DS. The shared key and each node's unique
node ID are generated by the DS when a node presents itself to the DS,
i.e. when it calls the `publish-node` method provided by the DS
JSON-RPC/HTTPS server [3].

A node typically republish itself, i.e. calls the `publish-node`
method repeatedly to renegotiate a new shared secret key to the
DS. The interval between renegotiations must not exceed the TTL
returned by the `publish-node` method, or else the DS will purge the
node from the overlay network.

The following sections describe the different 48 bytes protocol
messages.

## 2) Node Registration

The DS must have external port availll....

The node registration is done by each node after it has called the
`publish-node` method (see above) and is done to inform the DS about
the external ip-address and UDP port which the node listens on, i.e. a
node typically sits behind a NAT/firewall.

This external ip-address and UDP port is used by the DS when it needs
to reach out to node to orchestrate the establishment of an encrypted
tunnel to another node (See "Node-node Tunnel Establishment"
below). The external ip-address and UDP port is used as endpoints for
the encrypted node-node tunnels. Note: The protocol messages sent
between nodes are described in a separate document [4].

To register itself a node sends a `ds-register` message to the DS
until it gets a `node-registered` message in the return from the DS
with a matching `message ID`. This is done each time the node
renegotiate its shared secret key with the DS (see above).

```
Node                            Directory Server                            Node
  ------------ ds-register ------------>
  ------------ ds-register ------------>
  ------------ ds-register ------------>
  ...
  <--------- node-registered -----------
```

### 2.1) Message: *ds-register* (74 bytes)

Direction: `node -> directory server`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                            Node Id                                            |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x00         |                              Message ID                               |
|     32|  256|
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|                                    Random Bytes (42 bytes)
|     52|  416|
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

### 2.2) Message: *node-registered*  (74 bytes)

Direction: `directory server -> node`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                            Node Id                                            |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x00         |                              Message ID                               |
|     32|  256|
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|                                    Random Bytes (42 bytes)
|     52|  416|
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

## 3) Node keepalive handling towards DS

Most nodes sits behind a NAT/firewall and the DS needs to be able
to reach the node on its external ip-address and UDP port as described
in "Node registration" above.

To keep the UDP port open in the node's firewall the node must now and
then send a keepalive message to the DS (each ~10 seconds) [5].

SImple version of UDP hole punchin ,i.e. teh DS is requeired to to
publiah UDP port and ip adress..........

nodes external ip-address and port and the node must a make sure that
the firwall is open for incoming


 Most nodes sits behind
a firewall and this is a way to



and the UDP port is closed in the process, UDP hole punching employs the transmission of periodic keep-alive packets, each renewing the life-time counters in the UDP state machine of the NAT.



```
Node                            Directory Server                            Node
  ----------- ds-keepalive ------------>
  ----------- ds-keepalive ------------>
  ----------- ds-keepalive ------------>
...
```

### 3.1) Message: *ds-keepalive* (74 bytes)

Direction: `node -> [directory server]`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                            Node Id                                            |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x01         |
|     32|  256|
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|                                    Random Bytes (45 bytes)
|     52|  416|
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

## 4) Tunnel Establishment

```
Node                            Directory Server                            Node
  -------- ds-establish-tunnel -------->
                                        ------- node-establish-tunnel ------->
                                        <------- ds-tunnel-established -------
  <------ node-tunnel-established ------
```

### 4.1) Message: *ds-establish-tunnel* (74 bytes)

Direction:  `node -> directory server`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                          Src Node Id                                          |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x02         |                              Message ID                               |
|     32|  256|                                          Dest Node ID                                         |
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|
|     52|  416|                                    Random Bytes (38 bytes)
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

### 4.2) Message: *node-establish-tunnel* (74 bytes)

Direction: `directory server -> node`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                      Directory Server ID                                      |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x01         |                              Message ID                               |
|     32|  256|                                          Src Node ID                                          |
|     36|  288|                                         Src IP Address                                        |
|     40|  320|                Src Port Number                |
|     44|  352|
|     48|  384|
|     52|  416|
|     56|  448|                                      Shared Key (32 bytes)
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

### 4.3) Message: *ds-tunnel-established* (74 bytes)

Direction: `node -> directory server`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                          Dest Node Id                                         |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x03         |                              Message ID                               |
|     32|  256|                                          Src Node ID                                          |
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|
|     52|  416|                                     Random Bytes (38 bytes)
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

### 4.4) Message: *node-tunnel-established* (74 bytes)

Direction: `directory server -> node`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                      Directory Server ID                                      |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x02         |                               Message ID                              |
|     32|  256|                                          Dest Node ID                                         |
|     36|  288|                                        Dest IP Address                                        |
|     40|  320|                Dest Port Number               |
|     44|  352|
|     48|  384|
|     52|  416|
|     56|  448|                                      Shared Key (32 bytes)
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

## 5) Get Neighbours (Experimental)

```
Node                            Directory Server                            Node
  <-------- node-get-neighbours --------
  ----------- ds-neighbours ----------->
  ----------- ds-neighbours ----------->
  ----------- ds-neighbours ----------->
  ...
```

### 5.1) Message: *node-get-neighbours* (74 bytes)

Direction: `directory server -> node`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                      Directory Server ID                                      |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x03         |                              Message ID                               |
|     32|  256|
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|
|     52|  416|                                    Random Bytes (42 bytes)
|     56|  448|
|     60|  480|
|     64|  512|
|     68|  544|
|     72|  576|                                               |
```

### 5.2) Message: *ds-neighbours* (< 512 bytes)

Direction: `node -> directory server`

```
|Offsets|Octet|           0           |           1           |           2           |           3           |
|  Octet|  Bit|00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|
|      0|    0|                                      Directory Server ID                                      |
|      4|   32|
|      8|   64|
|     12|   96|                                        Nonce (24 bytes)
|     16|  128|
|     20|  160|
|     24|  192|                                                                                               |
|     28|  224|          0x04         |                              Message ID                               |
|     32|  256|                Fragment Counter               |                 Fragment Size                 |
|     36|  288|
|     40|  320|
|     44|  352|
|     48|  384|
|     52|  416|
|     56|  448|                                 Fragment (Fragment Size bytes)
|     60|  480|                     (If Fragment Size < 480 bytes it is the last fragment)
|     64|  512|
|     68|  544|
|     72|  576|
...
|     508|4064|                                                                                              |
```

## 5) Get Route Entries (Experimental)

```
Node                            Directory Server                            Node
  <------- node-get-route-entries ------
  --------- ds-route-entries ---------->
  --------- ds-route-entries ---------->
  --------- ds-route-entries ---------->
  ...
```

Same as the *node-get-neighbours* and *ds-route-entries* messages but
with the message types `0x04` and `0x05` respectively.


## References

[1] http://nacl.cr.yp.to/stream.html
[2] http://en.wikipedia.org/wiki/Cryptographic_nonce
[3] ds-json-rpc-server.md
[4] node-node-udp-protocol.md
[5] http://en.wikipedia.org/wiki/UDP_hole_punching