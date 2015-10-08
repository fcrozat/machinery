
## inspect-container — Inspect Container

### SYNOPSIS

`machinery inspect-container` [OPTIONS] IMAGENAME

`machinery inspect-container` [OPTIONS] IMAGEID

`machinery` help inspect-container


### DESCRIPTION

The `inspect-container` command analysis a container image by creating, starting and inspecting a container from the provided image
and generates a system description from the gathered data. After the inspection the container will be killed and removed again.
This approach ensures that no containers and images are affected by the inspection.

Right now we support only images from the type `docker`, which is set as default.

The system data is structured into scopes, controlled by the
`--scope` option.

**Note**:
Machinery will always inspect all specified scopes, and skip scopes which
trigger errors.


### ARGUMENTS

  * `IMAGENAME / IMAGEID` (required):
    The name or id of the image to be inspected. The name / id will also be
    used as the name of the stored system description unless another name is
    provided with the `--name` option.


### OPTIONS

  * `-n NAME`, `--name=NAME` (optional):
    Store the system description under the specified name.

  * `-s SCOPE`, `--scope=SCOPE` (optional):
    Inspect system for specified scope.
    See the [Scope section](#Scopes) for more information.

  * `-e SCOPE`, `--exclude-scope=EXCLUDE-SCOPE` (optional):
    Inspect system for all scopes except the specified scope.
    See the [Scope section](#Scopes) for more information.

  * `-x`, `--extract-files` (optional):
    Extract changed configuration and unmanaged files from the inspected system.
    Shortcut for the combination of `--extract-changed-config-files`,
    `--extract-unmanaged-files`, and `--extract-changed-managed-files`

  * `--extract-changed-config-files` (optional):
    Extract changed configuration files from the inspected system.

  * `--extract-unmanaged-files` (optional):
    Extract unmanaged files from the inspected system.

  * `--extract-changed-managed-files` (optional):
    Extract changed managed files from inspected system.

  * `--skip-files` (optional):
    Do not consider given files or directories during inspection. Either provide
    one file or directory name or a list of names separated by commas. You can
    also point to a file which contains a list of files to filter (one per line)
    by adding an '@' before the path, e.g.

      $ `machinery` inspect-container --skip-files=@/path/to/filter_file myhost

    If a filename contains a comma it needs to be escaped, e.g.

      $ `machinery` inspect-container --skip-files=/file\\,with_comma myhost

    **Note**: File or directory names are not expanded, e.g. '../path' is taken
      literally and not expanded.

  * `--verbose` (optional):
    Display the filters which are used during inspection.


### PREREQUISITES

  * Inspecting a container requires an image of the defined container-type specified by the name or id.

  * The system to be inspected needs to have the following commands:

    * `rpm`
    * `zypper` or `yum`
    * `rsync`
    * `chkconfig`
    * `cat`
    * `sed`
    * `find`

### EXAMPLES

  * Inspect docker-container `myhost` and save system description under name 'MySystem':
    
    $ `machinery` inspect-container --name=MySystem myhost

  * Inspect docker-container `076f46c1bef1` and save system description under name 'MySecondSystem':

    $ `machinery` inspect-container --name=MySecondSystem 076f46c1bef1

  * Extracts changed managed files and saves them:

    $ `machinery` inspect-container --scope=changed-managed-files --extract-files myhost
