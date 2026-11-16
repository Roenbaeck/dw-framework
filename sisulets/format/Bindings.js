var part = source.nextPart();
var field, fields = [];
var prefix = source.datafiletype == 'widechar' ? 'N' : '';
while (field = part.nextTerm()) {
    var eol = part.hasMoreTerms() ? '' : source.fieldterminator;
    var delimiter = (field.delimiter ? field.delimiter : '') + eol;
    var quote = delimiter.match(/"/) ? "'" : '"';
    fields.push({
        name: field.name,
        size: field.size,
        fixed: !!field.size,
        type: prefix + (field.size ? 'CharFixed' : 'CharTerm'),
        terminator: quote + delimiter + quote
    });
}
return JSON.stringify({
    format: {
        fields: fields,
        columnType: source.datafiletype == 'widechar' ? 'SQLNVARCHAR' : 'SQLVARYCHAR'
    }
});
