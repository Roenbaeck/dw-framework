    var firstPart = source.firstPart();
    var terms = [];
    for (var i = 0; firstPart.terms && i < firstPart.terms.length; i++) {
        terms.push({ name: firstPart.term[firstPart.terms[i]].name });
    }
    function nullable(part, name) {
        for (var n = 0; part.keys && n < part.keys.length; n++) {
            var partKey = part.key[part.keys[n]];
            if (partKey.components && partKey.components.indexOf(name) >= 0) return 'not null';
        }
        return 'null';
    }
    var parts = [];
    for (var p = 0; p < source.parts.length; p++) {
        var part = source.part[source.parts[p]], keys = [], partTerms = [], calculations = [];
        for (var k = 0; part.keys && k < part.keys.length; k++) {
            var key = part.key[part.keys[k]], components = [], keyConcat = '';
            for (var c = 0; key.components && c < key.components.length; c++) {
                var component = key.component[key.components[c]];
                components.push({ of: component.of });
                if (c) keyConcat += ' + CHAR(183) + ';
                keyConcat += 'CONVERT(varchar(max), [' + component.of + '], 126)';
            }
            keys.push({ name: key.name, type: key.type, components: components, concat: keyConcat });
        }
        var regex = part.charskip ? '.{' + part.charskip + '}' : (part.pattern ? part.pattern : '');
        var pivots = '';
        for (var t = 0; part.terms && t < part.terms.length; t++) {
            var term = part.term[part.terms[t]];
            var nulls = term.nulls ? term.nulls : (part.nulls ? part.nulls : '');
            if (t) pivots += ', ';
            pivots += '[' + (t + 1) + ']';
            if (term.pattern) regex += term.pattern.escape();
            else if (term.size) regex += '(.{' + term.size + '})';
            else if (term.delimiter) regex += '(.*?)' + term.delimiter.escape();
            else regex += '(.*)';
            partTerms.push({
                name: term.name,
                format: term.format,
                nullable: nullable(part, term.name),
                isKey: nullable(part, term.name) == 'not null',
                nulls: nulls.escape(),
                position: t + 1,
                transformation: term._term ? term._term.trim().escape() : '[' + term.name + ']'
            });
        }
        for (var j = 0; part.calculations && j < part.calculations.length; j++) {
            var calculation = part.calculation[part.calculations[j]];
            calculations.push({
                name: calculation.name,
                format: calculation.format,
                nullable: nullable(part, calculation.name),
                hasExpression: !!calculation._calculation,
                expression: calculation._calculation ? calculation._calculation.trim() : '',
                persisted: calculation.persisted == 'false' ? '' : 'PERSISTED'
            });
        }
        var keyCheck = part.keyCheck ? part.keyCheck : 'true';
        var typeCheck = part.typeCheck ? part.typeCheck : 'true';
        parts.push({
            name: part.name,
            qualified: part.qualified,
            keys: keys,
            terms: partTerms,
            calculations: calculations,
            hasCalculations: calculations.length > 0,
            hasQuery: !!part._part,
            query: part._part ? part._part.trim().escape() : '',
            regex: regex,
            pivots: pivots,
            checkKeys: keyCheck == 'true' && keys.length > 0,
            checkTypes: typeCheck == 'true',
            splitSourceToTarget: METADATA ? sisulate(sourceMetadataSourceToTargetTemplate, JSON.stringify({
                database: METADATABASE,
                sourceName: "'" + part.qualified + "_Split'",
                sourceType: "'View'",
                sourceCreated: 'DEFAULT',
                targetName: "'" + part.qualified + "_Typed'",
                targetType: "'Table'",
                targetCreated: 'DEFAULT'
            })) : ''
        });
    }
    function begin(suffix) {
        if (!METADATA) return '';
        return sisulate(sourceMetadataBeginTemplate, JSON.stringify({
            database: METADATABASE,
            workName: source.qualified + suffix,
            hasName: !!source.name,
            name: source.name
        }));
    }
    return JSON.stringify({
        source: {
            name: source.name,
            qualified: source.qualified,
            escapedXml: source._xml.replace(/'/g, "''"),
            rowlength: source.rowlength ? source.rowlength : 'max',
            format: source.format,
            codepage: source.codepage,
            datafiletype: source.datafiletype,
            fieldquote: source.fieldquote,
            fieldterminator: source.fieldterminator,
            rowterminator: source.rowterminator,
            firstrow: source.firstrow,
            present: {
                format: !!source.format,
                codepage: !!source.codepage,
                datafiletype: !!source.datafiletype,
                fieldquote: !!source.fieldquote,
                fieldterminator: !!source.fieldterminator,
                rowterminator: !!source.rowterminator,
                firstrow: !!source.firstrow
            },
            firstPart: { qualified: firstPart.qualified, terms: terms },
            parts: parts
        },
        sourceSchema: S_SCHEMA,
        sourceDatabase: VARIABLES.SourceDatabase,
        hasSourceDatabase: !!VARIABLES.SourceDatabase,
        sisulaPath: VARIABLES.SisulaPath,
        formatFile: VARIABLES.FormatFile,
        hasFormatFile: !!VARIABLES.FormatFile,
        isBulk: source.split == 'bulk',
        isRegex: source.split == 'regex',
        isChar: source.datafiletype == 'char',
        maxlen: MAXLEN,
        timestamp: TIMESTAMP,
        generated: String(new Date()),
        username: VARIABLES.USERNAME,
        computer: VARIABLES.COMPUTERNAME,
        domain: VARIABLES.USERDOMAIN,
        metadata: METADATA,
        metadatabase: METADATABASE,
        sourceMeta: {
            beginRaw: begin('_CreateRawTable'),
            beginRawSplit: begin('_CreateRawSplitTable'),
            beginInsertView: begin('_CreateInsertView'),
            beginBulk: begin('_BulkInsert'),
            beginSplitViews: begin('_CreateSplitViews'),
            beginTyped: begin('_CreateTypedTables'),
            beginAddKeys: begin('_AddKeysToTyped'),
            beginSplitRaw: begin('_SplitRawIntoTyped'),
            bulkSourceToTarget: METADATA ? sisulate(sourceMetadataSourceToTargetTemplate, JSON.stringify({
                database: METADATABASE,
                sourceName: '@filename',
                sourceType: "'File'",
                sourceCreated: '@lastModified',
                targetName: "'" + source.qualified + "_Insert'",
                targetType: "'View'",
                targetCreated: 'DEFAULT'
            })) : '',
            end: METADATA ? sisulate(sourceMetadataEndTemplate, JSON.stringify({ database: METADATABASE })) : ''
        }
    });
