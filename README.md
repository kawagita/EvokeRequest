EvokeRequest
===============

This script downloads files on command line. Retrieving files from FTP or HTTP site runs by only Powershell on Windows,
even so you must work on the environment in which downloaders haven't been installed yet.

## Usage

`.\EvokeRequest.ps1` with an array of URL strings would be executed on command line, and that state is displayed to
error console during a remote file is downloaded to the local.

<p>
  <img alt="Download" src="https://github.com/kawagita/EvokeRequest/raw/master/download.gif"/>
</p>

When Ctrl-C is pressed in progress, writing to a local file is suspended immediately, and that's removed from a saving
directory if `-Dispose` was specified. Otherwise, for the remaining as an incomplete file, the next downloading could be
resumed from the same site by `-Continue`.

<p>
  <img alt="Suspend" src="https://github.com/kawagita/EvokeRequest/raw/master/suspend.png"/>
</p>

All messages to error console are suppressed by `-Quiet` however only the progress of a downloading is able to displayed
by `-ShowProgress`, and then a file name is moving on the side by `-ShowMarquee`. You would be noted the end of a download
approaching easily if seconds are specified with `-BlinkingTime`.

<p>
  <img alt="Marquee" src="https://github.com/kawagita/EvokeRequest/raw/master/marquee.gif"/>
</p>

To display the detailed information about this script:

    man .\EvokeRequest.ps1 -Detailed

## Feature

This script outputs an information object for each download target following the last message if `-Verbose` is specified.
It's displayed to standard output unless received by a variable or pipeline.

<p>
  <img alt="Verbose" src="https://github.com/kawagita/EvokeRequest/raw/master/verbose.png"/>
</p>

Those informations are storing to a custoum object. About the details of downloading a file from FTP or HTTP server,
that structure and members are as follows.

- Location [Object]: linked list of locations (so finally Redirecion is $null)
  - Url [Uri]: doanload URL
  - Redirection [Object]:
    - Url [Uri]: redirected URL
    - Redirection [Object]:  
      ...
- LocalName [String]: local file name
- ContentType [String]: (only HTTP) media type in Content-Type header
- ContentParameters [Hashtable]: (only HTTP) parameters following a media type
- ContentDisposition [Object]: (only HTTP with `-ContentDisposition`)
  - DispositionType [String]: disposition type in Content-Disposition header
  - DispositionParameters [Hashtable]: parameters following a disposition type
- ContentOffset [long]: file position from which downloading is started
- ContentLength [long]: length up to which a file is downloaded, or -1 if unknown
- ByteLength [long]: length of byte data written to a local file
- LastModified [DateTime]: time at which a file is modified on server
- Cookies [Net.CookieContainer]: (only HTTP with `-Cookies`) cookies in response
- Condition [String]: condition of a download target
- StartTime [DateTime]: start time for a download target
- EndTime [DateTime]: end time for a download target

<p>
  <img alt="FTP Directory" src="https://github.com/kawagita/EvokeRequest/raw/master/ftp_directory.png"/>
</p>

About the details of reading the information from a FTP directory, please see below.

- Location [Object]:
  - Url [Uri]: FTP directory's URL
- DirectoryList [Object[]]:
  - ItemType [String]: "File", "Directory", or "Link"
  - Date [String]: last modified date of a file or directory
  - Length [long]: (only "File") file size
  - Name [String]: file or directory name
  - LinkTarget [String]: (only "Link") target for symbolic or hard link  
      ...
- Condition [String]: condition of a list target
- StartTime [DateTime]: start time for a list target
- EndTime [DateTime]: end time for a list target

### Condition

Condition represents the status of downloading a remote file or listing a FTP directory for each target by this script.
If targets are retried for a failure, the following list of conditions is as a reference.

* Completed - downloading or listing is completed but may be restricted by `-Quota`.
* Aborted - writing byte data to a local file is aborted by I/O error or Ctrl-C.
* Redirected - URL redirections are not reached to the end by `-MaxRedirect`.
* Not Modified - a remote file hasn't been modified and not downloaded by `-Newer`.
* Not Found - a remote file or directory is not found on server.
* No Access - login failed or authentication is required on server.
* Arleady Exists - a downloaded file arleady exists on the local.
* Disconnected - connection error occured or timed out.
* Unknown - downloading or listing failed and target is unknown state.

## Installation

`.\EvokeRequest.zip` is downloaded and extracted to a suitable directory. This must be placed with `en-US` or your locale's
directory (same as [Cultureinfo]::CurrentCulture.Name) to which the message file `EvokeMessage.psd1` is prepared.

## Note

Run the following line if any scripts can not be executed on your system:

    Set-ExecutionPolicy RemoteSigned -Scope Process

## License

This script is published under the MIT License.
