# Data that drives the create step picker registration for this plugin.
my %retrieve = (
    label       => "Retrieve Artifactory's artifact",
    procedure   => "Retrieve Artifact",
    description => "Retrieve an artifact from artifactory.",
    category    => "System"
);

my %publish = (
    label       => "Publish Artifactory's artifact",
    procedure   => "Publish Artifact",
    description => "Publish an artifact from artifactory.",
    category    => "System"
);

@::createStepPickerSteps = (\%retrieve);
@::createStepPickerSteps = (\%publish);
