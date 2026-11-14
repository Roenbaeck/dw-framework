function scalarProperties(object) {
    var result = {}, property;
    for (property in object) {
        if (typeof object[property] === 'string') result[property] = object[property];
    }
    return result;
}

function presentProperties(object) {
    var result = {}, property;
    for (property in object) {
        if (typeof object[property] === 'string') result[property] = !!object[property];
    }
    return result;
}

var result = scalarProperties(workflow);
result.escapedXml = workflow._xml.replace(/'/g, "''");
result.jobs = [];
for (var i = 0; i < workflow.jobs.length; i++) {
    var sourceJob = workflow.job[workflow.jobs[i]];
    var resolvedJob = scalarProperties(sourceJob);
    resolvedJob.present = presentProperties(sourceJob);
    resolvedJob.steps = [];
    for (var k = 0; sourceJob.jobsteps && k < sourceJob.jobsteps.length; k++) {
        var sourceStep = sourceJob.jobstep[sourceJob.jobsteps[k]];
        var resolvedStep = scalarProperties(sourceStep);
        resolvedStep.present = presentProperties(sourceStep);
        resolvedStep.command = sourceStep._jobstep ? sourceStep._jobstep.replace(/'/g, "''") : '';
        resolvedJob.steps.push(resolvedStep);
    }
    result.jobs.push(resolvedJob);
}
return JSON.stringify({ workflow: result, metadata: METADATA, metadatabase: METADATABASE });
