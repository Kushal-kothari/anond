var anond = {};

anond.loadNeighbours = function(loadHandler) {
    var self = this;
    var networkTopologyHandler = function(networkTopology) {
        var nodes = new Array();

        for (var i = 0; i < networkTopology.length; i++)
            nodes[i] = {"id": networkTopology[i].na};

        var links = new Array();
        var k = 0;

        for (var i = 0; i < networkTopology.length; i++) {
            if(networkTopology[i].peers == null)
                continue;
            var source =
                self._nodeIndex(networkTopology[i].na, networkTopology);
            self._assert(source != -1, "source must not be -1");
            for (var j = 0; j < networkTopology[i].peers.length; j++) {
                if(networkTopology[i].peers[j]["incoming-peer"])
                    continue;
                else {
                    var target =
                        self._nodeIndex(networkTopology[i].peers[j].na,
                                        networkTopology);
                    self._assert(target != -1, "target must not be -1");
                    links[k++] =
                        {"from": networkTopology[i].na,
                         "to": networkTopology[i].peers[j].na,
                         "source": source,
                         "target": target,
                         "path-cost": networkTopology[i].peers[j]["path-cost"]};
                }
            }
        }

        loadHandler({nodes: nodes, links: links});
    };

    self._getNetworkTopology(networkTopologyHandler);
};

anond.loadRoutes = function(loadHandler) {
    var self = this;
    var networkTopologyHandler = function(networkTopology) {
        var nodes = new Array();

        for (var i = 0; i < networkTopology.length; i++)
            nodes[i] = {"na": networkTopology[i].na};

        var links = new Array();
        var l = 0;

        for (var i = 0; i < networkTopology.length; i++)
            for (var j = 0; j < networkTopology[i]["route-entries"].length;
                 j++) {
                var from = networkTopology[i].na;
                for (var k = 0;
                     k < networkTopology[i]["route-entries"][j].length; k++) {
                    var to = networkTopology[i]["route-entries"][j][k];
                    if (self._linkMember(from, to, links))
                        break;
                    var source = self._nodeIndex(from, networkTopology);
                    self._assert(source != -1, "source must not be -1");
                    var target = self._nodeIndex(to, networkTopology);
                    self._assert(target != -1, "target must not be -1");
                    var fromPathCost =
                        self._lookupPathCost(from, to, networkTopology);
                    var toPathCost =
                        self._lookupPathCost(to, from, networkTopology);
                    var pathCost = null;
                    if (fromPathCost != null && toPathCost != null)
                        pathCost = (fromPathCost+toPathCost)/2;
                    else {
                        if (fromPathCost != null)
                            pathCost = fromPathCost;
                        else
                            pathCost = toPathCost;
                    }
                    self._assert(pathCost != null, "pathCost must not be null");
                    links[l++] = {"from": from,
                                  "to": to,
                                  "source": source,
                                  "target": target,
                                  "path-cost": pathCost};
                    from = to;
                }
            }

        loadHandler({nodes: nodes, links: links});
    };

    self._getNetworkTopology(networkTopologyHandler);
};

/*
 * Helper functions
 */

anond._nodeIndex = function(na, networkTopology) {
    for (var i = 0; i < networkTopology.length; i++)
        if (networkTopology[i].na == na)
            return i;
    return -1;
};

anond._linkMember = function(from, to, links) {
    for (var i = 0; i < links.length; i++)
        if ((links[i].from == from && links[i].to == to) ||
            (links[i].from == to && links[i].to == from))
            return true
    return false;
};

anond._lookupPathCost = function(from, to, networkTopology) {
    var peers = null;
    for (var i = 0; i < networkTopology.length; i++) {
        if (networkTopology[i].na == from) {
            peers = networkTopology[i].peers;
            break;
        }
    }
    if (peers == null)
        return null;
    for (var i = 0; i < peers.length; i++)
        if (peers[i].na == to)
            return peers[i]["path-cost"];
    return null;
};

anond._getNetworkTopology = function(resultHandler) {
    $.post("/jsonrpc",
           JSON.stringify({
               jsonrpc: "2.0",
               method: "get-network-topology",
               id: 1}),
           function(response) {
               if (response.result)
                   resultHandler(response.result);
               else
                   if (response.error)
                       alert(response.error.message);
           },
           "json");
};

anond._assert = function(condition, message) {
    if (!condition)
        $.error(msg);
};