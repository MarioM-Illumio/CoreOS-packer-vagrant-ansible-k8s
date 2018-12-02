### Build haproxy docker image

Official HAProxy image with an option to include config file using environment variable.
Set the HAPROXY_CONFIG environment variable pointing to the location of your config file.
Note: The config file must be present in the container. So be sure to copy/mount it.
