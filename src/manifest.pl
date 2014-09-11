@files = (
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
    # ['//property[propertyName="AbstractStorage.pm"]/value', 'Storage/AbstractStorage.pm'],
    ['//property[propertyName="Artifactory.pm"]/value', 'Storage/Artifactory.pm'],
    # ['//property[propertyName="Nexus.pm"]/value', 'Storage/Nexus.pm'],

    ['//procedure[procedureName="Configure"]/step[stepName="Configure"]/command' , 'configure.pl'],

    ['//procedure[procedureName="Retrieve Artifact"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'forms/retrieve.xml'],
    ['//procedure[procedureName="Retrieve Artifact"]/step[stepName="Retrieve Artifact"]/command' , 'retrieve.pl'],

    ['//procedure[procedureName="Publish Artifact"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'forms/publish.xml'],
    ['//procedure[procedureName="Publish Artifact"]/step[stepName="Publish Artifact"]/command' , 'publish.pl']
);
