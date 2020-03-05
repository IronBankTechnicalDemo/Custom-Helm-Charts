# Jira Software Helm Chart

This helm chart can be used to deploy a standalone instance of Jira Software based on the CloudFit Jira Software image. Please note that Jira Software is different from Jira Core and this helm chart is not meant to be used with the Jira Core image.


## CloudFit Documentation

### Completing Jira setup

<https://teams.microsoft.com/l/file/A00AAE44-A0B2-494D-ABDA-7A4A31B002A5?tenantId=b846a774-f39d-4a2d-9366-f3dda22c6bf0&fileType=pdf&objectUrl=https%3A%2F%2Fcloudfitsoftware.sharepoint.com%2Fsites%2FO365_JPODSOP%2FShared%20Documents%2FJira%2FJiraSetup.pdf&baseUrl=https%3A%2F%2Fcloudfitsoftware.sharepoint.com%2Fsites%2FO365_JPODSOP&serviceName=teams&threadId=19:b35cde2fe4e240759f7a7c6820d628ab@thread.skype&groupId=43984e83-2167-4916-867b-1054ce77101a>

This document was based on Jira Core, but the setup process is very similar.

### Managing Jira

<https://teams.microsoft.com/l/file/3A16D9E0-51B7-47F4-BDE0-7856F5DE02A3?tenantId=b846a774-f39d-4a2d-9366-f3dda22c6bf0&fileType=docx&objectUrl=https%3A%2F%2Fcloudfitsoftware.sharepoint.com%2Fsites%2FO365_JPODSOP%2FShared%20Documents%2FJira%2FManaging%20Jira.docx&baseUrl=https%3A%2F%2Fcloudfitsoftware.sharepoint.com%2Fsites%2FO365_JPODSOP&serviceName=teams&threadId=19:b35cde2fe4e240759f7a7c6820d628ab@thread.skype&groupId=43984e83-2167-4916-867b-1054ce77101a>

This document is a work in progress.


## Prerequisites

There are no prerequisites to use this chart in its default configuration, however you will need an empty database available to complete the setup.

Jira has strict requirements for the collation and encoding scheme for its databases. For example, a postgresql database should be created in the following way:

```sql
CREATE DATABASE jira WITH ENCODING 'UNICODE' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
```

Depending on how the database is created, it may also be necessary to set the permissions of the database.

```sql
ALTER DATABASE jira OWNER TO jira;
grant all privileges on database jira to jira;
ALTER SCHEMA public OWNER TO jira;
```

## Customization

The values.yaml file can be edited to change various aspects of the deployment.

### Networking

#### Using a Reverse Proxy (Running behind an Ingress Controller)

By default, Jira runs on port 8080. The default Jira connector defined in /opt/atlassian/jira/conf/server.xml is shown below:

<Connector port="8080" relaxedPathChars="[]|" relaxedQueryChars="[]|{}^&#x5c;&#x60;&quot;&lt;&gt;"
    maxThreads="150" minSpareThreads="25" connectionTimeout="20000" enableLookups="false"
    maxHttpHeaderSize="8192" protocol="HTTP/1.1" useBodyEncodingForURI="true" redirectPort="8443"
    acceptCount="100" disableUploadTimeout="true" bindOnInit="false"/>

In order to run Jira behind a reverse proxy, additional parameters for the proxy must be added to the connector definition. For example:

<Connector port="8080" relaxedPathChars="[]|" relaxedQueryChars="[]|{}^&#x5c;&#x60;&quot;&lt;&gt;"
    maxThreads="150" minSpareThreads="25" connectionTimeout="20000" enableLookups="false"
    maxHttpHeaderSize="8192" protocol="HTTP/1.1" useBodyEncodingForURI="true" redirectPort="8443"
    acceptCount="100" disableUploadTimeout="true" bindOnInit="false"
    scheme="https" proxyName="jira.apps" proxyPort="443" secure="true"/>

These parameters can be added to the connector definition automatically by adding the relevant environment variables to the envVars section of values.yaml:

    - X_PROXY_NAME - The proxy hostname. This value must match the hostname provided in the ingress section of values.yaml.
    - X_PROXY_PORT - The proxy port. This will likely be 80 if traffic is unsecure or 443 if traffic is secured with TLS.
    - X_PROXY_SCHEME - The proxy traffic scheme. This must be either "http" if traffic is unsecure or "https" if traffic is secured with TLS.

These values (and all values in the envVars section) will be copied as-is to the environment variables section of the container within the deployment. The entrypoint script of the Jira Software image looks for these environment variables. If found, the script uses xmlstarlet to modify the connector defintion before starting Jira.

**Note:** When running Jira behind a proxy, the proxy timeout must be increased to at least 300 seconds or more. It is **very** important to set this timeout, as Jira (and other atlassian software) can take significant time setting up initial database. Smaller timeouts will panic Jira setup process and it will terminate. You can change the timeout of ingress controllers by adding "haproxy.router.openshift.io/timeout = 5m" to the annotation field under ingress in values.yaml.

More detail on reverse proxy configuration can be found here: - <https://confluence.atlassian.com/jirakb/configure-jira-server-to-run-behind-a-nginx-reverse-proxy-426115340.html>

Please note that the example in the documentation is specific for an Nginx reverse proxy, but that the connector definition changes must be made regardless of the type of reverse proxy used.

#### Importing SSL Certificates

If the application is secured with TLS, then the certificate must be imported into Jira's keystore. This enables the use of application links, user directories, and other features that involved connectivity to other Java apps.

When certs.enabled is set to true, the secret with the name that matches cert.secretName will be injected into the location specified in cert.mountPath via configmap. At this time, the TLS cert is the only certificate that can be imported as it is the only cert created during the deployment (It is possible to import existing certificates, but we are not currently operationg in that way). There is currently no mechanism in place for importing other certificates into the keystore.

### Heap Size

Java memory parameters can be modified by adding the following environment variables to the envVars section of values.yaml:

    - JAVA_OPTS
    - CATALINA_OPTS

Depending on the version of Jira Software, the installer/run scripts will look at one of these two environment variables. Since it is not immediately obvious which version looks at which variable, it is best to set both for every version.

Jira requires a large amount of RAM in order to perform its indexing and run properly. You can find the server requirements [here](https://confluence.atlassian.com/adminjiraserver086/jira-applications-installation-requirements-990552762.html). It is advisable to increase the Java heap size and the memory to the maximum allowable values for your environment.

For reference, A succesful deployment was not achieved until the following parameters were used:

    ```yaml
    envVars:
      JAVA_OPTS: "-Dfile.encoding=UTF-8 -Xms1024m -Xmx8192m -XX:MaxMetaspaceSize=512m -XX:MaxDirectMemorySize=10m"
      CATALINA_OPTS: "-Dfile.encoding=UTF-8 -Xms1024m -Xmx8192m -XX:MaxMetaspaceSize=512m -XX:MaxDirectMemorySize=10m"

    resources:
      cpuRequest: 3000m
      cpuLimit: 4000m
      memoryRequest: 10240Mi
      memoryLimit: 12488Mi
    ```

These parameters appear to be right on the cusp though, as subsequent deployments have had mixed results. Use these values as a bare minimum.

### Filebeat Logging

Filebeat logging is disabled by default, but it can be enabled by setting filebeat.enabled equal to true in the values.yaml.

When filbeat logging is enabled, a filebeat sidecar container will be created with the purpose of monitoring certain Jira log locations and sending the output to a logstash pipeline, specified by the logstashHost parameter. Filebeat will run whether the target pipeline exists or not.

To specify a specific log location for Filebeat to monitor, you can use the following "parameter block" under logConfig:

    ```yaml
    - mountName: jira-app-logs
    mountPath: /var/atlassian/application-data/jira/log
    logPaths:
        - /var/atlassian/application-data/jira/log/atlassian-jira-security.log
        - /var/atlassian/application-data/jira/log/atlassian-jira.log
    logParams:
        multiline.pattern: ^[0-9]{4}-[0-9]{2}-[0-9]{2}
        multiline.negate: true
        multiline.match: after
    ```

    - mountName - The name of the mounted volume to create
    - mountPath - The directory of the log files to monitor. Used to create a mounted volume for the container.
    - logPaths - Filepath to individual log files to monitor. These paths are written directly to the Filebeat config file that will be injected via configmap.
    - logParams - Filebeat parameters to specify how a set of logs should be read/processed. These values will be written directly to the filebeat config file that will be injected via configmap.

Keep in mind that multiple "parameter blocks" can be used in order to specify multiple log locations. You can see an example of this in the values.yaml file.

## Outstanding Issues & Future Work

Issues with the current helm chart and improvements can be made are specified here.

### Readiness/Liveness Checks

Readiness and Liveness checks are already incorporated into this chart, however the application cannot complete its setup with them enabled. This is caused by the /status endpoint not being available while Jira is bootstrapping its database. These checks will need to be modified to accomodate that task.

### Database Initialization

Jira Software stores its database connection information in a dbconfig.xml file stored in JIRA_HOME. If this file does not exist, then a database setup page will be displayed during setup. The information entered on this page is used to generate a dbconfig.xml file. It is possible to inject a dbconfig.xml file via configmap and skip the database setup screen.

The mechanism for injecting the database configuration file is in place, however it is disabled by default. This is because Jira Software has never been able to complete its setup successfully when the file is not autogenerated. There may be discrepencies between the file generated with the configmap versus the file generated by Jira Software.

### Clustering

Jira Software can be run in datacenter mode to enable clustering. Pieces of this process exist in the helm chart and underlying image. Enabling datacenter mode in values.yaml triggers the creation of additional environment variables and volumes. These environment variables are used to create a cluster.properties file that Jira uses to locate other nodes. Unfortunately, clustering has not been successful so far. The clustering process needs to be investigated further.

### Plugins

There is a mechanism for installing plugins built into the helm chart/underlying image, however this would require internet activity. We do not currently rely on any plugins, but if we choose to make use of them, then it may be advisable to look for a different solution.
