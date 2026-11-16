var resolvedLoads = [], load, map;
while (load = target.nextLoad()) {
    var maps = [], natural = [], surrogate = [], metadata = [], others = [];
    while (map = load.nextMap()) {
        maps.push(map);
        switch (map.as) {
            case 'natural key': natural.push(map); break;
            case 'surrogate key': surrogate.push(map); break;
            case 'metadata': metadata.push(map); break;
            default: others.push(map);
        }
    }

    var attributes = [], knotToAttributes = {}, knottedCount = 0;
    var toAnchor = !!load.toAnchor();
    if (toAnchor) {
        while (map = load.nextMap()) {
            if (map.knot) {
                knottedCount++;
                if (!knotToAttributes[map.knot]) knotToAttributes[map.knot] = [];
                knotToAttributes[map.knot].push(map);
            }
            if (map.isValueColumn()) {
                var attributeMnemonic = map.target.match(/^(..\_...)\_.*/)[1];
                var historized = false;
                for (var i = 0; i < others.length; i++) {
                    if (others[i].target == attributeMnemonic + '_ChangedAt') historized = true;
                }
                var knotMnemonic = map.knot ? map.knot.match(/^(...)\_.*/)[1] : '';
                var related = [];
                for (var r = 0; r < maps.length; r++) {
                    if (map != maps[r] && maps[r].target.indexOf(attributeMnemonic) == 0) {
                        related.push({ source: maps[r].source, target: maps[r].target });
                    }
                }
                attributes.push({
                    source: map.source,
                    target: map.target,
                    attribute: map.attribute,
                    mnemonic: attributeMnemonic,
                    anchorReference: attributeMnemonic + '_' + load.anchorMnemonic + '_ID',
                    hasKnot: !!map.knot,
                    knot: map.knot,
                    knotMnemonic: knotMnemonic,
                    historized: historized,
                    resolvedSource: map.knot ? knotMnemonic + '_ID' : map.source,
                    resolvedTarget: map.knot ? attributeMnemonic + '_' + knotMnemonic + '_ID' : map.target,
                    knownInput: map.attribute + (map.knot ? '__Known_Knot_Lookup.Match' : '__Known_not_Null.Values'),
                    unknownInput: map.attribute + (map.knot ? '__Unknown_Knot_Lookup.Match' : '__Unknown_not_Null.Values'),
                    related: related
                });
            }
        }
    }

    var groups = [], knot;
    for (knot in knotToAttributes) {
        var groupMaps = [];
        for (var g = 0; g < knotToAttributes[knot].length; g++) {
            var groupMap = knotToAttributes[knot][g];
            groupMaps.push({ source: groupMap.source, attribute: groupMap.attribute });
        }
        groups.push({ name: knot, mnemonic: knot.match(/^(...)\_.*/)[1], maps: groupMaps });
    }

    var allMaps = [], naturalKeys = [], naturalSources = [], surrogateSources = [], seenNatural = [], seenSurrogate = [];
    for (var m = 0; m < maps.length; m++) {
        allMaps.push({ source: maps[m].source, target: maps[m].target });
        if (seenNatural.indexOf(maps[m].source) < 0) {
            seenNatural.push(maps[m].source);
            naturalSources.push({ source: maps[m].source });
        }
        if (seenSurrogate.indexOf(maps[m].source) < 0 && surrogate.indexOf(maps[m]) < 0) {
            seenSurrogate.push(maps[m].source);
            surrogateSources.push({ source: maps[m].source });
        }
    }
    for (var n = 0; n < natural.length; n++) {
        naturalKeys.push({ source: natural[n].source, target: natural[n].target });
    }
    var before = load.sql && load.sql.before;
    var after = load.sql && load.sql.after;
    resolvedLoads.push({
        source: load.source,
        target: load.target,
        qualified: load.qualified,
        targetTable: load.targetTable,
        anchorMnemonic: load.anchorMnemonic,
        loadingSql: load._load ? load._load : 'SELECT * FROM ' + load.source,
        hasBefore: !!before,
        before: before && before._sql,
        hasAfter: !!after,
        after: after && after._sql,
        hasMetadata: !!metadata[0],
        metadataSource: metadata[0] && metadata[0].source,
        noKeys: natural.length == 0 && surrogate.length == 0,
        naturalToAnchor: natural.length > 0 && toAnchor,
        surrogateToAnchor: natural.length == 0 && surrogate.length > 0 && toAnchor,
        surrogateSource: surrogate[0] && surrogate[0].source,
        surrogateTarget: surrogate[0] && surrogate[0].target,
        maps: allMaps,
        naturalKeys: naturalKeys,
        naturalSources: naturalSources,
        surrogateSources: surrogateSources,
        attributes: attributes,
        hasKnots: knottedCount > 0,
        knotThreads: knottedCount + 1,
        dataThreads: 2 * attributes.length + 1,
        knots: groups
    });
}
return JSON.stringify({
    loads: resolvedLoads,
    sourceDatabase: VARIABLES.SourceDatabase,
    sourceServer: VARIABLES.SourceServer,
    targetDatabase: VARIABLES.TargetDatabase,
    targetServer: VARIABLES.TargetServer,
    targetSchema: VARIABLES.TargetSchema,
    generated: String(new Date()),
    username: VARIABLES.USERNAME,
    computer: VARIABLES.COMPUTERNAME,
    domain: VARIABLES.USERDOMAIN
});
