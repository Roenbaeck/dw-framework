var resolved = {
    name: target.name,
    namePresent: !!target.name,
    database: target.database,
    escapedXml: target._xml.replace(/'/g, "''"),
    loads: []
};
var load;
while (load = target.nextLoad()) {
    var maps = [], natural = [], surrogate = [], metadata = [], others = [], current;
    var hasDeletables = false;
    while (current = load.nextMap()) {
        var map = {
            source: current.source,
            target: current.target,
            role: current.as,
            roleComment: current.as ? ' (as ' + current.as + ')' : '',
            deletableMarker: current.deletable === 'true' ? '[D]' : '',
            deletable: current.deletable === 'true',
            deletableColumn: '[Deletable_' + (current.target || '').substring(0, 6) + ']',
            isStatic: current.as == 'static',
            isHistory: current.as == 'history'
        };
        maps.push(map);
        if (map.deletable) hasDeletables = true;
        switch (current.as) {
            case 'natural key': natural.push(map); break;
            case 'surrogate key': surrogate.push(map); break;
            case 'metadata': metadata.push(map); break;
            case 'opinion':
                if (target.temporalization === 'crt') others.push(map);
                break;
            default: others.push(map);
        }
    }
    var updateConditions = [];
    for (var i = 0; i < others.length; i++) {
        if (others[i].role != 'history' && others[i].role != 'opinion') updateConditions.push(others[i]);
    }
    var before = load.sql && load.sql.before;
    var after = load.sql && load.sql.after;
    resolved.loads.push({
        source: load.source,
        target: load.target,
        type: load.type,
        qualified: load.qualified,
        maps: maps,
        hasDeletables: hasDeletables,
        hasBefore: !!before,
        before: before && before._sql,
        hasAfter: !!after,
        after: after && after._sql,
        isInsert: load.type == 'insert',
        hasQuery: !!load._load,
        query: load._load,
        hasCondition: !!load.condition,
        condition: load.condition,
        insertMaps: natural.concat(surrogate, metadata, others),
        keyMaps: natural.concat(surrogate),
        mergeInsertMaps: natural.concat(others, metadata),
        updateConditions: updateConditions,
        updateMaps: others.concat(metadata)
    });
}
return JSON.stringify({
    target: resolved,
    sourceSchema: S_SCHEMA,
    targetSchema: T_SCHEMA,
    sourceDatabase: VARIABLES.SourceDatabase,
    hasSourceDatabase: !!VARIABLES.SourceDatabase,
    generated: String(new Date()),
    username: VARIABLES.USERNAME,
    computer: VARIABLES.COMPUTERNAME,
    domain: VARIABLES.USERDOMAIN,
    metadata: METADATA,
    metadatabase: METADATABASE,
    unitemporal: target.temporalization === 'uni'
});
