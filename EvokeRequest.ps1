#Requires -Version 2.0

# Download the file for URLs from FTP or HTTP site.
# Copyright(C) 2019 Yoshinori Kawagita
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

<#
.SYNOPSIS
    Download the file for URL(s) from FTP or HTTP site.

.DESCRIPTION
    Remote files are download from FTP or HTTP site of URLs in a specified list
    and adjusted with timestamp on each site. During file downloading, that state
    is displayed and finally the information object is output.

.PARAMETER UrlList
    Use this URLs in a list as download target.

.PARAMETER Directory
    Save downloaded files to this directory.

.PARAMETER InputFile
    Read download URLs from this file.

.PARAMETER OutputFile
    Write log messages to this file.

.PARAMETER OutputAppend
    Append messages to output file.

.PARAMETER ConnectTimeout
    Set the connect timeout to this time.

.PARAMETER StartPos
    Start downloading files from this offset.

.PARAMETER Continue
    Resume downloading files which exist on the local.

.PARAMETER Newer
    Overwrite only files newer than the local.

.PARAMETER NoClobber
    Don't overwrite any files on the local.

.PARAMETER Dispose
    Dispose files which are not downloaded completely.

.PARAMETER Spider
    Don't download anything.

.PARAMETER Quota
    Restrict download byte length to this size.

.PARAMETER FtpUser
    Set FTP user to this name, instead of 'anonymous'.

.PARAMETER FtpPassword
    Set FTP password to this characters.

.PARAMETER NoPassiveFtp
    Don't use "passive" transfer mode in FTP session.

.PARAMETER HttpUser
    Set HTTP user to this name.

.PARAMETER HttpPassword
    Set HTTP password to this characters.

.PARAMETER NoHttpKeepAlive
    Send a request without using HTTP persistent connection.

.PARAMETER HttpProxy
    Access HTTP site using a proxy of this URL.

.PARAMETER ProxyUser
    Set Proxy user to this name.

.PARAMETER ProxyPassword
    Set Proxy password to this characters.

.PARAMETER MaxRedirect
    Continue HTTP's URL redirections until this number.

.PARAMETER Headers
    Add this parameters to HTTP request header.

.PARAMETER UserAgent
    Set this parameter as User-Agent field into HTTP request header.

.PARAMETER Referer
    Set this parameter as Referer field into HTTP request header.

.PARAMETER Cookies
    Set this cookie container into HTTP request header.

.PARAMETER DefaultPage
    Set the default page name for which HTTP's URL path ends with a slash
    to this name, instead of 'index.html'.

.PARAMETER QueryAppendExtensions
    Concatenate a query string with the local name which has an extension
    in this list or is alphanumeric characters.

.PARAMETER ContentDisposition
    Attach a file name of Content-Disposition field in HTTP response header
    to the local name if possible.

.PARAMETER BlinkingTime
    Display blinking ETA less than this time with the progress.

.PARAMETER ShowMarquee
    Display moving file name on the side of a progress bar.

.PARAMETER ShowProgress
    Display a progress bar to error console in any quiet mode.

.PARAMETER Quiet
    Never display a downloading state to error console.

.PARAMETER Verbose
    Output the information object for each download target.
#>

Param(
    [Uri[]]$UrlList=@(),
    [String]$Directory="",
    [String]$InputFile="",
    [String]$OutputFile="",
    [Switch]$OutputAppend=$false,
    [String]$ConnectTimeout="30000",
    [String]$StartPos="0",
    [Switch]$Continue=$false,
    [Switch]$Newer=$false,
    [Switch]$NoClobber=$false,
    [Switch]$Dispose=$false,
    [Switch]$Spider=$false,
    [String]$Quota="",
    [String]$FtpUser='anonymous',
    [String]$FtpPassword="",
    [Switch]$NoPassiveFtp=$false,
    [String]$HttpUser="",
    [String]$HttpPassword="",
    [Switch]$NoHttpKeepAlive=$false,
    [Uri]$HttpProxy=$null,
    [String]$ProxyUser="",
    [String]$ProxyPassword="",
    [int]$MaxRedirect=20,
    [String[]]$Headers=@(),
    [String]$UserAgent="",
    [String]$Referer="",
    [Net.CookieContainer]$Cookies=$null,
    [String]$DefaultPage='index.html',
    [String[]]$QueryAppendExtensions=@(),
    [Switch]$ContentDisposition=$false,
    [String]$BlinkingTime="0s",
    [Switch]$ShowMarquee=$false,
    [Switch]$ShowProgress=$false,
    [Switch]$Quiet=$false,
    [Switch]$Verbose=$false
);

$DOWNLOAD_MESSAGE_FILE = 'EvokeMessage.psd1';
$DOWNLOAD_BUFFER_SIZE = 2048;

$DownloadCulture = [Globalization.CultureInfo]::CurrentCulture;
Import-LocalizedData -BindingVariable MessageList -FileName $DOWNLOAD_MESSAGE_FILE `
                     -UICulture $DownloadCulture.Name 2> $null;
if (-not $?) {
    $DownloadCulture = New-Object Globalization.CultureInfo 'en-US';
    Import-LocalizedData -BindingVariable MessageList -FileName $DOWNLOAD_MESSAGE_FILE `
                         -UICulture $DownloadCulture.Name 2> $null;
    if (-not $?) {
        $MessageList = @{
            # Error messages for the option specification
            NO_SUPPORTED_URL = "No supported URL '{0}'.";
            NOT_CHANGED_TO_VALUE = "'{0}' are not changed to a value.";
            UNUSABLE_CHARS_INCLUDED = "Unusable characters are included in '{0}'.";
            # Fields on the progress bar
            PROGRESS_ETA_FIELD = '    eta {0,-7}';
            PROGRESS_TIME_FIELD = '    in {0,-8}';
        }
    }
    [Threading.Thread]::CurrentThread.CurrentCulture = $DownloadCulture;
    [Threading.Thread]::CurrentThread.CurrentUICulture = $DownloadCulture;
}

$PROGRESS_REFRESH_MILLISECONDS = 200.0;
$PROGRESS_LABEL_WIDTH = 20;
$PROGRESS_LABEL_FOREGROUND_COLOR = [ConsoleColor]::Yellow;
$PROGRESS_BAR_LIMIT = 40;
$PROGRESS_BAR_FOREGROUND_ADVANCED_COLOR = [ConsoleColor]::Cyan;
$PROGRESS_BAR_FOREGROUND_FINISHED_COLOR = [ConsoleColor]::DarkCyan;
$PROGRESS_BAR_BACKGROUND_COLOR = [ConsoleColor]::DarkBlue;
$PROGRESS_TIME_BLINKING_COLOR = [ConsoleColor]::Red;

# Returns the conversion of the specified unit characters.
#
# $UnitChars - a unit string
# $LoworderValueTable - the table of loworder values for unit characters
# return the conversion of the specified unit characters

function GetUnitConversion([String[]]$UnitChars, [Object]$LoworderValueTable) {
    return New-Object PSObject -Prop @{
        UnitChars = $UnitChars;
        LoworderValueTable = $LoworderValueTable;
    } | Add-Member -PassThru ScriptMethod GetLoworderValue {
        Param([String]$unitchar);
        return $this.LoworderValueTable.Item($unitchar);
    } | Add-Member -PassThru ScriptMethod ToFractionLoworder {
        Param([String]$fraction, [String]$unitchar);
        return [double]$fraction * $this.GetLoworderValue($unitchar);
    };
}

# Returns a long value parsed for the specified unit string.
#
# $UnitString - a unit string
# $UnitConversion - the conversion of a unit
# return a long value parsed for the specified unit string if valid, otherwise, -1

$UNIT_REGEX = [Regex]('^([0-9]+)(\.[0-9]+)? *([A-Za-z])?$');

function ParseUnitLong([String]$UnitString, [Object]$UnitConversion) {
    $unitmatch = $UNIT_REGEX.Match($UnitString);
    if ($unitmatch.Success) {
        $longval = [long]0;
        if ([long]::TryParse($unitmatch.Groups[1].Value, [ref]$longval)) {
            $fraction = $unitmatch.Groups[2].Value;
            $unitchars = $UnitConversion.UnitChars;
            $unitchar = $unitmatch.Groups[3].Value;
            if (-not [String]::IsNullOrEmpty($unitchar)) {
                $unitindex = $unitchars.Length - 1;
                do {
                    if ($unitindex -lt 0) {
                        return -1;
                    } elseif ($unitchar -eq $unitchars[$unitindex]) {
                        break;
                    }
                    $unitindex--;
                } while ($true);
                $value = [double]$longval;
                $unitval = $UnitConversion.GetLoworderValue($unitchar);
                if ($value -gt ([long]::MaxValue / $unitval)) {
                    return -1;
                }
                $value *= $unitval;
                $loworder = $UnitConversion.ToFractionLoworder($fraction, $unitchar);
                if ($value -gt ([long]::MaxValue - $loworder)) {
                    return -1;
                }
                $value += $loworder;
                $unitindex--;
                while ($unitindex -ge 0) {
                    $unitval = $UnitConversion.GetLoworderValue($unitchars[$unitindex]);
                    if ($value -gt ([long]::MaxValue / $unitval)) {
                        return -1;
                    }
                    $value *= $unitval;
                    $unitindex--;
                }
                $longval = [long]$value;
            } elseif ([double]$fraction -ge 0.5) {
                if ($longval -gt ([long]::MaxValue - 1)) {
                    return -1;
                }
                $longval++;
            }
            return $longval;
        }
    }
    return -1;
}

# Returns a long value parsed for the string of the specified unit byte.
#
# $UnitByte - the string of unit byte
# return a long value parsed for the string of unit byte if valid, otherwise, -1

$UNIT_BYTE_CHARS = @('K', 'M', 'G', 'T', 'P', 'E');
$UNIT_BYTE_LENGTH = [long]1024;
$UNIT_BYTE_LOWERDER_VALUE_TABLE = New-Object PSObject `
| Add-Member -PassThru ScriptMethod Item {
    return $UNIT_BYTE_LENGTH;
};
$UNIT_BYTE_CONVERSION = GetUnitConversion $UNIT_BYTE_CHARS $UNIT_BYTE_LOWERDER_VALUE_TABLE;

function ParseByteLength([String]$UnitByte) {
    return ParseUnitLong $UnitByte $UNIT_BYTE_CONVERSION;
}

# Returns the string of unit byte to which the specified byte length is formatted.
#
# $ByteLength - a byte length
# $DecimalPlaces - decimal places by which a fraction with one, two, three, or four
#                  digit integer is formatted from 0 to 2
# return the string of unit byte to which the specified byte length is formatted

$UNIT_BYTE_DECIMAL_PLACE_FORMATS = @('0', '0.0', '0.00');

function ToUnitByteString([long]$ByteLength, [int[]]$DecimalPlaces) {
    if ($ByteLength -ge 0) {
        if ($ByteLength -lt $UNIT_BYTE_LENGTH) {
            return [String]$ByteLength;
        }
        $digitmaxes = @(10.0, 100.0, 1000.0);
        $rounderrs = @(0.5, 0.05, 0.005);
        $value = [double]$ByteLength;
        $count = 0;
        do {
            $value /= [double]$UNIT_BYTE_LENGTH;
            if ([long]$value -lt $UNIT_BYTE_LENGTH) {
                $unit = $UNIT_BYTE_CHARS[$count];
                $digit = 0
                do {
                    # Formats a long value to each digit maximum rounding by decimal places
                    $decimalplace = [int]$DecimalPlaces[$digit];
                    if ($value -lt ($digitmaxes[$digit] - $rounderrs[$decimalplace])) {
                        $digitfmt = $UNIT_BYTE_DECIMAL_PLACE_FORMATS[$decimalplace] + $unit;
                        return $value.ToString($digitfmt);
                    }
                    $digit++;
                } while ($digit -lt $digitmaxes.Length);

                # Formats a long value less than 1024
                $decimalplace = [int]$DecimalPlaces[$digit];
                $digitfmt = $UNIT_BYTE_DECIMAL_PLACE_FORMATS[$decimalplace] + $unit;
                return $value.ToString($digitfmt);
            }
            $count++;
        } while ($count -lt $UNIT_BYTE_CHARS.Length);
    }
    return "";
}

# Returns a millisecond parsed for the string of the specified unit time.
#
# $UnitTime - the string of unit time
# return a millisecond parsed for the string of the specified unit time if valid,
# otherwise, -1

$UNIT_TIME_CONVERSION = GetUnitConversion @('s', 'm', 'h') `
                                          @{ 's' = 1000; 'm' = 60; 'h' = 60; };

function ParseMilliseconds([String]$UnitTime) {
    $milliseconds = ParseUnitLong $UnitTime $UNIT_TIME_CONVERSION;
    if ($milliseconds -le [int]::MaxValue) {
        return $milliseconds;
    }
    return -1;
}

# Returns the string with units to which the specified time span is formatted.
#
# $TimeSpan - a time span
# $LeadingWidth - the width by which the time of a leading unit is formatted
# $TrailingWidth - the width by which the time of a trailing unit is formatted
# $SecondDecimalPlaces - decimal places by which a fraction of milliseconds with
#                        one digit second or others is formatted from 0 to 3
# return the string with units to which the specified time span is formatted

$TIME_HOUR_MAX = [int]99;
$TIME_SECOND_DECIMAL_PLACE_FORMATS = @('0', '0.0', '0.00', '0.000');

function ToUnitTimeString([TimeSpan]$TimeSpan, [int]$LeadingWidth, [int]$TrailingWidth,
                          [int[]]$SecondDecimalPlaces=$null) {
    if ([Math]::Ceiling($TimeSpan.TotalHours) -le $TIME_HOUR_MAX) {
        $time = "";
        $unitwidths = @($LeadingWidth, $TrailingWidth);
        $unit = 0;
        do {
            $width = $unitwidths[$unit];
            if ($TimeSpan.Hours -gt 0) {
                $time += "{0,${width}}h" -f $TimeSpan.Hours;
                $TimeSpan -= New-TimeSpan -Hours $TimeSpan.Hours;
            } elseif ($TimeSpan.Minutes -gt 0) {
                $time += "{0,${width}}m" -f $TimeSpan.Minutes;
                $TimeSpan -= New-TimeSpan -Minutes $TimeSpan.Minutes;
            } else {
                if (($unit -eq 0) -and ($SecondDecimalPlaces -is [int[]])) {
                    $rounderrs = @(0.5, 0.05, 0.005, 0.0005);
                    $decimalplace = $SecondDecimalPlaces[0];
                    $seconds = $TimeSpan.TotalSeconds;
                    $fraction = 0.95;
                    if ($seconds -ge (10.0 - $rounderrs[$decimalplace])) {
                        $decimalplace = [int]$SecondDecimalPlaces[1];
                    } elseif ($seconds -lt $fraction) {
                        # Increases digits of only a fraction so as not to be zero
                        $decimalplace = $TIME_SECOND_DECIMAL_PLACE_FORMATS.Length;
                        $digit = 1;
                        do {
                            $fraction /= 10;
                            if ($seconds -gt $fraction) {
                                $decimalplace = $digit;
                                break;
                            }
                            $digit++;
                        } while ($digit -le $TIME_SECOND_DECIMAL_PLACE_FORMATS.Length);
                    }
                    $secondfmt = $TIME_SECOND_DECIMAL_PLACE_FORMATS[$decimalplace] + 's';
                    return $seconds.ToString($secondfmt);
                }
                return $time + ("{0,${width}}s" -f $TimeSpan.Seconds);
            }
            $unit++;
            if ($unit -ge $unitwidths.Length) {
                return $time;
            }
            $time += ' ';
        } while ($true);
    }
    return "";
}

# Returns the string to which unusable characters are encoded in the specified name.
#
# $FileName - a file name
# return the string to which unusable characters are encoded in the specified name

$UNUSABLE_CHARS = @('"', '\*', '/', ':', '<', '>', '\?', '\\', '\|');
$UNUSABLE_CHAR_PERCENT_ENCODINGS = @(
    '%22', '%2A', '%2F' , '%3A', '%3C', '%3E', '%3F', '%5C', '%7C'
);

function EncodeUnusableChars([String]$FileName) {
    for ($count = 0; $count -lt $UNUSABLE_CHARS.Length; $count++) {
        $FileName = $FileName -replace $UNUSABLE_CHARS[$count],
                                       $UNUSABLE_CHAR_PERCENT_ENCODINGS[$count];
    }
    return $FileName;
}

# Logger of verbose messages to an output file or error console

$LOGGER_VALID_DATA_REGEX = [Regex]('^([1-9][0-9]*|[A-Za-z].*)$');

$Logger = New-Object PSObject -Prop @{
    Buffer = $null;
    Writer = $null;
    NewLine = "";
} | Add-Member -PassThru ScriptMethod 'Open' {
    Param([String]$logpath="", [Switch]$append=$false);
    $this.Buffer = New-Object Text.StringBuilder;
    if ($logpath -ne "") {
        $encoding = New-Object Text.UTF8Encoding($false);
        $this.Writer = New-Object IO.StreamWriter($logpath, $append, $encoding);
    } else {
        $this.Writer = [Console]::Error;
    }
    $this.NewLine = $this.Writer.NewLine;
} | Add-Member -PassThru ScriptMethod 'AppendFormat' {
    Param([String]$format, [String]$value1="", [String]$value2="");
    if ($this.Writer -ne $null) {
        [void]$this.Buffer.AppendFormat($format, @($value1, $value2));
    }
} | Add-Member -PassThru ScriptMethod 'Append' {
    Param([String]$value);
    if ($this.Writer -ne $null) {
        [void]$this.Buffer.Append($value);
    }
} | Add-Member -PassThru ScriptMethod 'AppendLine' {
    Param([String]$value);
    $this.Append($value + $this.NewLine);
} | Add-Member -PassThru ScriptMethod 'AppendValidFormat' {
    Param([String]$format, [String]$value, [String]$replacement="");
    if ($LOGGER_VALID_DATA_REGEX.IsMatch($value)) {
        $this.AppendFormat($format, $value);
    } else {
        $this.Append($replacement);
    }
} | Add-Member -PassThru ScriptMethod 'AppendByteLength' {
    Param([String]$format, [String]$value);
    $this.AppendFormat($format, (ToUnitByteString $value @(1)));
} | Add-Member -PassThru ScriptMethod 'AppendFtpCommand' {
    Param([String]$command, [String]$value1="", [String]$value2="");
    if ($command.StartsWith('TYPE')) {
        $spaces = '  ';
    } else {
        $spaces = '    ';
    }
    $this.AppendFormat('==> {0}', $command);
    $this.AppendValidFormat(' {0}', $value1);
    $this.Append(' ... ');
    $this.AppendValidFormat('{0}', $value2, ($MessageList.FTP_COMMAND_DONE + $spaces));
} | Add-Member -PassThru ScriptMethod 'Flush' {
    if ($this.Writer -ne $null) {
        $this.Writer.Write($this.Buffer.ToString());
        [void]$this.Buffer.Remove(0, $this.Buffer.Length);
    }
} | Add-Member -PassThru ScriptMethod 'FlushLine' {
    $this.AppendLine();
    $this.Flush();
} | Add-Member -PassThru ScriptMethod 'Announce' {
    Param([String]$format, [DateTime]$time);
    if ($this.Writer -ne $null) {
        [void]$this.Buffer.Insert(0, $time.ToString($format) + '  ');
        $this.FlushLine();
    }
} | Add-Member -PassThru ScriptMethod 'Close' {
    if ($this.Writer -ne $null) {
        $this.Writer.Close();
    }
};

# Returns the object of a downloaded location for the specified URL.
#
# $Url - the URL of a downloaded file
# return the object of a downloaded location for a URL if supported, otherwise, $null

$TARGET_URL_FTP_SCHEMES = @([Uri]::UriSchemeFtp);
$TARGET_URL_HTTP_SCHEMES = @([Uri]::UriSchemeHttp, [Uri]::UriSchemeHttps);
$TARGET_URL = 'Url';
$TARGET_REDIRECTION = 'Redirection';

function GetDownloadLocation([Uri]$Url) {
    if (($TARGET_URL_FTP_SCHEMES -notcontains $Url.Scheme) `
        -and ($TARGET_URL_HTTP_SCHEMES -notcontains $Url.Scheme)) {
        return $null;
    }
    $location = New-Object PSObject -Prop @{
        $TARGET_URL = $Url;
    };
    if ($TARGET_URL_FTP_SCHEMES -contains $Url.Scheme) {
        $location | Add-Member -Force ScriptMethod 'ToString' {
            $this.Url.AbsoluteUri;
        };
    } else {
        $location `
        | Add-Member -PassThru NoteProperty $TARGET_REDIRECTION $null `
        | Add-Member -Force ScriptMethod 'ToString' {
            $this.Url.AbsoluteUri;
            if ($this.Redirection -ne $null) {
                $this.Redirection.ToString();
            }
        };
    }
    return $location;
}

# Returns the local name for the specified URL.
#
# $Url - the URL of a downloaded file
# $Options - download options
# return the local name for a URL, or $null if FTP's URL ends with a slash

$LOCAL_NAME_QUERY_APPENDED_SEPARATOR = '@';
$LOCAL_NAME_ALPHANUMERIC_REGEX = [Regex]('^[0-9A-Za-z_]+$');
$LOCAL_NAME_REGEX = [Regex]('(\.([^.]+))?$');

function GetDownloadLocalName([Uri]$Url, [Object]$Options) {
    # Sets the last path segment as a local name into the target
    if ($Url.LocalPath.EndsWith('/')) {
        if ($TARGET_URL_FTP_SCHEMES -contains $Url.Scheme) {
            return $null;
        }
        $name = $Options.DefaultPage;
    } else {
        $name = EncodeUnusableChars ($Url.LocalPath -replace '.*/', "");
    }
    if ($TARGET_URL_FTP_SCHEMES -notcontains $Url.Scheme) {
        # Appends a HTTP query string leading with '@' to the local name
        # for optional extensions or only alphanumeric characters
        $namematch = $LOCAL_NAME_REGEX.Match($name);
        if ($namematch.Groups[1].Success) {
            $extension = $namematch.Groups[2].Value;
            if ($Options.QueryAppendExtensions -notcontains $extension) {
                return $name;
            }
        } elseif (-not $LOCAL_NAME_ALPHANUMERIC_REGEX.IsMatch($name)) {
            return $name;
        }
        if (-not [String]::IsNullOrEmpty($Url.Query)) {
            $name += $LOCAL_NAME_QUERY_APPENDED_SEPARATOR `
                     + (EncodeUnusableChars $Url.Query.Substring(1));
        }
    }
    return $name;
}

# Returns the object of a download target for the specified URL.
#
# $Url - the URL of a downloaded file
# $Options - download options
# return the object of a download target for a URL if valid, otherwise, $null

$TARGET_LOCATION = 'Location';
$TARGET_LOCAL_NAME = 'LocalName';
$TARGET_CONTENT_TYPE = 'ContentType';
$TARGET_CONTENT_PARAMETERS = 'ContentParameters';
$TARGET_CONTENT_DISPOSITION = 'ContentDisposition';
$TARGET_CONTENT_DISPOSITION_TYPE = 'DispositionType';
$TARGET_CONTENT_DISPOSITION_PARAMETERS = 'DispositionParameters';
$TARGET_CONTENT_OFFSET = 'ContentOffset';
$TARGET_CONTENT_LENGTH = 'ContentLength';
$TARGET_BYTE_LENGTH = 'ByteLength';
$TARGET_LAST_MODIFIED = 'LastModified';
$TARGET_COOKIES = 'Cookies';
$TARGET_DIRECTORY_LIST = 'DirectoryList';
$TARGET_CONDITION = 'Condition';
$TARGET_CONDITION_COMPLETED = 'Completed';
$TARGET_CONDITION_ABORTED = 'Aborted';
$TARGET_CONDITION_REDIRECTED = 'Redirected';
$TARGET_CONDITION_NOT_MODIFIED = 'Not Modified';
$TARGET_CONDITION_NOT_FOUND = 'Not Found';
$TARGET_CONDITION_NO_ACCESS = 'No Access';
$TARGET_CONDITION_ARLEADY_EXISTS = 'Arleady Exists';
$TARGET_CONDITION_DISCONNECTED = 'Disconnected';
$TARGET_CONDITION_UNKONWN = 'Unknown';
$TARGET_START_TIME = 'StartTime';
$TARGET_END_TIME = 'EndTime';

function GetDownloadTarget([Uri]$Url, [Object]$Options) {
    if (-not $Url.IsAbsoluteUri) {
        return $null;
    }
    $urlstring = $Url.Scheme + [Uri]::SchemeDelimiter + $Url.Authority + $Url.PathAndQuery;
    $location = GetDownloadLocation ([Uri]$urlstring);
    if ($location -eq $null) {
        return $null;
    }
    $target = New-Object PSObject -Prop @{
        $TARGET_LOCATION = $location;
    };
    $name = GetDownloadLocalName $Url $Options;
    if ($name -ne $null) {
        # Adds the property of a local name and informations of a downloaded file
        $target | Add-Member NoteProperty $TARGET_LOCAL_NAME $name;
        if ($TARGET_URL_FTP_SCHEMES -notcontains $Url.Scheme) {
            $target | Add-Member -PassThru NoteProperty $TARGET_CONTENT_TYPE "" `
                    | Add-Member NoteProperty $TARGET_CONTENT_PARAMETERS @{};
            if ($Options.ContentDispositonAttached) {
                $target | Add-Member NoteProperty $TARGET_CONTENT_DISPOSITION $null;
            }
        }
        $target | Add-Member -PassThru NoteProperty $TARGET_CONTENT_OFFSET ([long]0) `
                | Add-Member -PassThru NoteProperty $TARGET_CONTENT_LENGTH ([long]-1) `
                | Add-Member -PassThru NoteProperty $TARGET_BYTE_LENGTH ([long]0) `
                | Add-Member NoteProperty $TARGET_LAST_MODIFIED $null;
        if ($TARGET_URL_FTP_SCHEMES -notcontains $Url.Scheme) {
            if ($Options.Cookies -is [Net.CookieContainer]) {
                $target | Add-Member NoteProperty $TARGET_COOKIES $Options.Cookies;
            }
        }
    } else {
        # Adds only an array to store the information of items in FTP directory
        $target | Add-Member NoteProperty $TARGET_DIRECTORY_LIST @();
    }
    $target | Add-Member NoteProperty $TARGET_CONDITION $TARGET_CONDITION_UNKONWN;
    return $target;
}

# Resolve the host name of the specified URL to IPv4 or IPv6 addresses.
#
# $Url - the URL of a downloaded file
# return $true if thee host name is resolved to IP addresses

$HostAdddressesTable = @{};

function ResolveHostName([Uri]$Url) {
    $idnhost = $Url.IdnHost; # .NET Framework 4.6 or later
    if ($idnhost -eq $null) {
        $idnhost = $Url.Host;
    }
    if ($Url.HostNameType -eq [UriHostNameType]::IPv4) {
        $Logger.AppendFormat($MessageList.CONNECTING_TO_HOST_ADDRESS, $Url.Host, $Url.Port);
        $Logger.FlushLine();
    } elseif ($Url.HostNameType -eq [UriHostNameType]::IPv6) {
        $Logger.AppendFormat($MessageList.CONNECTING_TO_IPV6_ADDRESS, $Url.Host, $Url.Port);
        $Logger.FlushLine();
    } else {
        $addresses = $HostAdddressesTable.Item($Url.Host);
        if ($addresses -eq $null) {
            $addresses = @();
            try {
                $Logger.AppendFormat($MessageList.RESOLVING_HOST_ADDRESS, $idnhost, $Url.Host);
                $Logger.Flush();
                ([Net.DNS]::GetHostEntry($Url.Host)).AddressList `
                | Where-Object {
                    $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork `
                    -or $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6;
                } | ForEach-Object {
                    if ($addresses.Length -gt 0) {
                        $Logger.Append(', ')
                    }
                    $addresses += $_;
                    $Logger.Append($_.IPAddressToString);
                };
                $HostAdddressesTable.Add($Url.Host, $addresses);
                $Logger.AppendLine();
                $Logger.AppendFormat($MessageList.CONNECTING_TO_HOST_ADDRESS,
                                     $idnhost, $Url.Port);
                $Logger.FlushLine();
            } catch [Net.Sockets.SocketException] {
                # Fails to resolve the host name by GetHostEntry before sending a request
                $Logger.Append($MessageList.RESOLVING_FAILED);
                $Logger.FlushLine();
                $Logger.AppendFormat($MessageList.UNABLE_TO_RESOLVE_HOST_ADDRESS, $idnhost);
                return $false;
            }
        } else {
            $Logger.AppendFormat($MessageList.REUSING_HOST_ADDRESS, $idnhost, $Url.Port);
            $Logger.FlushLine();
        }
    }
    return $true;
}

# Returns the FTP response received by the request of the specified URL.
#
# $Target - the object of a download target
# $Options - download options
# return the FTP response received by the request of the specified URL

$FTP_DOWNLOAD_FILE_METHODS = @(
    [Net.WebRequestMethods+Ftp]::GetDateTimestamp,
    [Net.WebRequestMethods+Ftp]::GetFileSize,
    [Net.WebRequestMethods+Ftp]::DownloadFile
);
$FTP_LIST_DIRECTORY_METHODS = @(
    [Net.WebRequestMethods+Ftp]::ListDirectoryDetails
);

$FTP_LOGIN_INCORRECT_STATUS_VALUES = @(
    [Net.FtpStatusCode]::SendPasswordCommand.value__, # 331
    [Net.FtpStatusCode]::NeedLoginAccount.value__,    # 332
    [Net.FtpStatusCode]::NotLoggedIn.value__          # 530
);
$FTP_CONNECTION_DISCONNECTED_STATUS_VALUES = @(
    [Net.FtpStatusCode]::CantOpenData.value__,     # 425
    [Net.FtpStatusCode]::ConnectionClosed.value__  # 426
);

function GetFtpResponse([ref]$Target, [Object]$Options) {
    $localname = $Target.Value.LocalName;
    $location = $Target.Value.Location;
    $offset = $Options.ContentOffset;
    if ($localname -ne $null) {
        $reqmethods = $FTP_DOWNLOAD_FILE_METHODS;
    } else {
        $reqmethods = $FTP_LIST_DIRECTORY_METHODS;
    }
    $reqcount = 0;
    $response = $null;

    $Logger.AppendFormat($MessageList.FTP_LOGGING_IN_AS, $Options.FtpCredential.UserName);
    $Logger.Flush();
    do {
        $request = [Net.FtpWebRequest]::Create($location.Url);
        $request.Credentials = $Options.FtpCredential;
        $request.UsePassive = $Options.FtpTransferMode -eq 'PASV';
        $request.Method = $reqmethods[$reqcount];
        if ($request.Method -eq [Net.WebRequestMethods+Ftp]::DownloadFile) {
            $request.ContentOffset = $offset;
        }
        $reqcount++;
        $response = $null;

        try {
            $response = $request.GetResponse();
            if ($reqcount -eq 1) {
                $Logger.AppendLine($MessageList.FTP_LOGGED_IN);
                $Logger.AppendFtpCommand('TYPE I');
            }
            switch ($request.Method) {
                ([Net.WebRequestMethods+Ftp]::GetDateTimestamp) {
                    $Target.Value.LastModified = $response.LastModified;
                    $timestamp = $response.LastModified.ToString('yyyyMMddhhmmss');
                    $Logger.AppendFtpCommand('MDTM', "", $timestamp);
                    if ($response.LastModified.CompareTo($Options.IfModifiedSince) -le 0) {
                        # Doesn't retrieve the remote file no newer than a local file
                        $Logger.FlushLine();
                        $Logger.AppendFormat($MessageList.FILE_NOT_MODIFIED, $localname);
                        $Target.Value.Condition = $TARGET_CONDITION_NOT_MODIFIED;
                        $response.Close();
                        return $null;
                    }
                }
                ([Net.WebRequestMethods+Ftp]::GetFileSize) {
                    $total = $response.ContentLength;
                    $Logger.AppendFtpCommand('SIZE', $localname, $total);
                    if ($total -gt 0) {
                        $length = $total - $offset;
                        if ($length -le 0) {
                            # Doesn't retrieve the remote file smaller than a local file
                            # or option specification with -StartPos
                            $Logger.FlushLine();
                            $Logger.AppendFormat($MessageList.FILE_ARLEADY_RETRIEVED,
                                                 $localname);
                            $Target.Value.ContentOffset = $total;
                            $Target.Value.ContentLength = 0;
                            $Target.Value.Condition = $TARGET_CONDITION_ARLEADY_EXISTS;
                            $response.Close();
                            return $null;
                        } else {
                            $Target.Value.ContentLength = $length;
                        }
                    } else {
                        $Target.Value.ContentLength = -1;
                    }
                }
                ([Net.WebRequestMethods+Ftp]::DownloadFile) {
                    $Target.Value.ContentOffset = $offset;
                    $Logger.AppendFtpCommand($Options.FtpTransferMode);
                    if ($offset -gt 0) {
                        $Logger.AppendFtpCommand('REST', $offset);
                        $Logger.AppendLine();
                    }
                    $Logger.AppendFtpCommand('RETR', $localname);
                }
                ([Net.WebRequestMethods+Ftp]::ListDirectoryDetails) {
                    $Logger.AppendFtpCommand($Options.FtpTransferMode);
                    $Logger.AppendLine();
                    $Logger.AppendFtpCommand('LIST');
                }
            }
            $Logger.FlushLine();

            if ($reqcount -lt $reqmethods.Length) {
                $response.Close();
            }
        } catch [Net.WebException] {
            if ($_.Exception.Status -ne [Net.WebExceptionStatus]::ProtocolError) {
                $Logger.FlushLine();
                throw;
            }
            # Fails to receive FTP response by GetResponse for a request
            $response = $_.Exception.Response;
            $statusval = $response.StatusCode.value__;
            if ($reqcount -eq 1) {
                if ($FTP_LOGIN_INCORRECT_STATUS_VALUES -contains $statusval) {
                    $Logger.Append($MessageList.FTP_LOGIN_INCORRECT);
                    $Logger.FlushLine();
                    $Logger.Append($MessageList.FTP_LOGIN_NEEDED);
                    $Target.Value.Condition = $TARGET_CONDITION_NO_ACCESS;
                    return $null;
                }
                $message = $response.WelcomeMessage;
                if (($message -is [String]) `
                    -and ($message.StartsWith([Net.FtpStatusCode]::LoggedInProceed.value__))) {
                    $Logger.Append($MessageList.FTP_LOGGED_IN);
                }
                $Logger.FlushLine();
            }
            if ($FTP_CONNECTION_DISCONNECTED_STATUS_VALUES -contains $statusval) {
                $Logger.Append($MessageList.CONNECTION_ERROR_OCCURS);
                $Target.Value.Condition = $TARGET_CONDITION_DISCONNECTED;
                return $null;
            }
            switch ($statusval) { # FTP server return codes
                ([Net.FtpStatusCode]::ActionNotTakenFileUnavailable.value__) { # 550
                    if ($localname -ne $null) {
                        $notfoundmsg = $MessageList.FILE_NOT_FOUND;
                    } else {
                        $notfoundmsg = $MessageList.FTP_DIRECTORY_NOT_FOUND;
                    }
                    $Logger.AppendFormat($notfoundmsg, $location.Url.LocalPath);
                    $Target.Value.Condition = $TARGET_CONDITION_NOT_FOUND;
                }
                default {
                    # Ignores error responses except for the last method
                    if ($request.Method -eq [Net.WebRequestMethods+Ftp]::GetDateTimestamp) {
                        $Logger.AppendFtpCommand('MDTM');
                        $Logger.FlushLine();
                        continue;
                    } elseif ($request.Method -eq [Net.WebRequestMethods+Ftp]::GetFileSize) {
                        $Logger.AppendFtpCommand('SIZE', $localname);
                        $Logger.FlushLine();
                        continue;
                    } else {
                        $Logger.Append($MessageList.FTP_ACTION_NOT_TAKE_PLACE);
                    }
                }
            }
            return $null;
        }
    } while ($reqcount -lt $reqmethods.Length);

    return $response;
}

# Reads the list of a FTP directory from the specified response into the specified target.
#
# $Target - the object of a download target
# $Response - a FTP response

$FTP_DIRECTORY_LIST_DATE = 'Date';
$FTP_DIRECTORY_LIST_ITEM_TYPE = 'ItemType';
$FTP_DIRECTORY_LIST_LENGTH = 'Length';
$FTP_DIRECTORY_LIST_NAME = 'Name';
$FTP_DIRECTORY_LIST_LINK_TARGET = 'LinkTarget';

$FTP_DIRECTORY_LIST_MONTH ='Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec'
$FTP_DIRECTORY_LIST_UNIX_REGEX = `
    [Regex]('^([-a-z])[-+*a-z]+ +[0-9]+( +[0-9A-Z_a-z]+){1,2} +([0-9]+)' `
            + "(( +(${FTP_DIRECTORY_LIST_MONTH}|[0-3]?[0-9]|[0-9]{4}|[0-9]{2}:[0-9]{2})){3})" `
            + ' +(.+)$');
$FTP_DIRECTORY_LIST_UNIX_MATCH_GROUP_INDEXES = @{
    $FTP_DIRECTORY_LIST_ITEM_TYPE = 1;
    $FTP_DIRECTORY_LIST_DATE = 4;
    $FTP_DIRECTORY_LIST_LENGTH = 3;
    $FTP_DIRECTORY_LIST_NAME = 7;
};
$FTP_DIRECTORY_LIST_UNIX_LINK_REGEX = [Regex]('^(.*[^ ]) +-> +(.+)$');
$FTP_DIRECTORY_LIST_WINDOWS_REGEX = `
    [Regex]('([-./0-9]{10} +[0-9]{2}:[0-9]{2}) +(<([A-Z]+)>|[,0-9]+) +(.*)$');
$FTP_DIRECTORY_LIST_WINDOWS_MATCH_GROUP_INDEXES = @{
    $FTP_DIRECTORY_LIST_ITEM_TYPE = 3;
    $FTP_DIRECTORY_LIST_DATE = 1;
    $FTP_DIRECTORY_LIST_LENGTH = 2;
    $FTP_DIRECTORY_LIST_NAME = 4;
};
$FTP_DIRECTORY_LIST_WINDOWS_LINK_REGEX = [Regex]('^(.*[^ ]) +\[(.+)\]$');

function ReadFtpDirectoryList([ref]$Target, [Net.FtpWebResponse]$Response) {
    $stream = $null;
    $reader = $null;
    try {
        $stream = $Response.GetResponseStream();
        $reader = New-Object IO.StreamReader($stream);
        do {
            $liststring = $reader.ReadLine();
            if ($liststring -eq $null) {
                break;
            }
            $indexes = $null;
            $listmatch = $FTP_DIRECTORY_LIST_UNIX_REGEX.Match($liststring);
            if ($listmatch.Success) {
                # Matches UNIX format like a ls command's output
                $indexes = $FTP_DIRECTORY_LIST_UNIX_MATCH_GROUP_INDEXES;
                $linkregex = $FTP_DIRECTORY_LIST_UNIX_LINK_REGEX;
            } else {
                $listmatch = $FTP_DIRECTORY_LIST_WINDOWS_REGEX.Match($liststring);
                if (-not $listmatch.Success) {
                    continue;
                }
                # Matches Windows format like a dir command's output
                $indexes = $FTP_DIRECTORY_LIST_WINDOWS_MATCH_GROUP_INDEXES;
                $linkregex = $FTP_DIRECTORY_LIST_WINDOWS_LINK_REGEX;
            }
            # Parses the original string into a date, type, size, and name
            $name = $listmatch.Groups[$indexes.Name].Value;
            $linktarget = $null;
            $item = New-Object PSObject -Prop @{
                $FTP_DIRECTORY_LIST_ITEM_TYPE = $null;
                $FTP_DIRECTORY_LIST_DATE = `
                    $listmatch.Groups[$indexes.Date].Value.Trim();
            } | Add-Member -PassThru -Force ScriptMethod 'ToString' {
                $this.Name;
            };
            switch -regex ($listmatch.Groups[$indexes.ItemType].Value) {
                '^(d|DIR)' {
                    $item.ItemType = 'Directory';
                    $item | Add-Member -Force ScriptMethod 'ToString' {
                        $this.Name + '/';
                    };
                    break;
                }
                '^(l|[A-Z]+)' {
                    $item.ItemType = 'Link';
                    $linkmatch = $linkregex.Match($name);
                    if (-not $linkmatch.Success) {
                        break;
                    }
                    $item | Add-Member -Force ScriptMethod 'ToString' {
                        $this.Name + ' -> ' + $this.LinkTarget;
                    };
                    $name = $linkmatch.Groups[1].Value;
                    $linktarget = $linkmatch.Groups[2].Value;
                }
                default {
                    $item.ItemType = 'File';
                    $item | Add-Member NoteProperty $FTP_DIRECTORY_LIST_LENGTH `
                                       ([long]$listmatch.Groups[$indexes.Length].Value);

                }
            }
            $item | Add-Member NoteProperty $FTP_DIRECTORY_LIST_NAME $name;
            if ($linktarget -ne $null) {
                $item | Add-Member NoteProperty $FTP_DIRECTORY_LIST_LINK_TARGET $linktarget;
            }
            $Target.Value.DirectoryList += $item;
        } while ($true);

        $Logger.Append($MessageList.FTP_DIRECTORY_LISTED);
        $Target.Value.Condition = $TARGET_CONDITION_COMPLETED;
    } catch [Net.WebException] {
        if ($_.Exception.Status -ne [Net.WebExceptionStatus]::ProtocolError) {
            throw;
        }
        # Fails to read byte data from FTP connection
        $statusval = $_.Exception.Response.StatusCode.value__;
        if ($FTP_CONNECTION_DISCONNECTED_STATUS_VALUES -contains $statusval) {
            $Logger.Append($MessageList.CONNECTION_ERROR_OCCURS);
            $Target.Value.Condition = $TARGET_CONDITION_DISCONNECTED;
        } else {
            $Logger.Append($MessageList.FTP_ACTION_NOT_TAKE_PLACE);
        }
    } finally {
        try {
            if ($stream -ne $null) {
                if ($reader -ne $null) {
                    $reader.Close();
                }
                $stream.Close();
            }
        } catch [Net.WebException] {
        }
    }
}

# HTTP expressions defined by Request for Comments

$HTTP_HEADER_WS = "[`t ]";
$HTTP_HEADER_OWS = "${HTTP_HEADER_WS}*";
$HTTP_HEADER_TOKEN = "[^`t ;]+"; # token to a space or semicollon
$HTTP_HEADER_CHARS = "[^`t ;]*"; # chars to a space or semicollon
$HTTP_HEADER_DQUOTE = '"';
$HTTP_HEADER_QUOTED_STRING = `
    "${HTTP_HEADER_DQUOTE}(\\.|[^${HTTP_HEADER_DQUOTE}\\])*${HTTP_HEADER_DQUOTE}";
$HTTP_HEADER_PARAMETER_FORMAT = "^({0})(${HTTP_HEADER_OWS};${HTTP_HEADER_OWS}" `
    + "(([^=]+)=(${HTTP_HEADER_TOKEN}|${HTTP_HEADER_QUOTED_STRING})))*$";

# Returns the hash table of attribute and value pairs from the specified match group.
#
# $AttributeGroup - a group of attributes
# $ValueGroup - a group of values
# return the hash table of attribute and value pairs from the specified match group.

function GetHttpParameters([Text.RegularExpressions.CaptureCollection]$AttributeCaptures,
                           [Text.RegularExpressions.CaptureCollection]$ValueCaptures) {
    $parameters = @{};
    for ($count = 0; $count -lt $AttributeCaptures.Count; $count++) {
        $attribute = $AttributeCaptures[$count].Value;
        $value = $ValueCaptures[$count].Value;
        if ($value.StartsWith($HTTP_HEADER_DQUOTE)) {
            $value = $value.Substring(1, $value.Length - 2);
        }
        $parameters.Add($attribute, $value);
    }
    return $parameters;
}

# Returns the HTTP response received by the request of the specified URL.
#
# $Target - the object of a download target
# $Options - download options
# return the HTTP response received by the request of the specified URL

$HTTP_CONTENT_TYPE_REGEX = `
    [Regex]($HTTP_HEADER_PARAMETER_FORMAT -f ("[^/]+/${HTTP_HEADER_TOKEN}"));
$HTTP_CONTENT_DISPOSITION_REGEX = `
    [Regex]($HTTP_HEADER_PARAMETER_FORMAT -f "${HTTP_HEADER_TOKEN}");

$HTTP_REDIRECTED_STATUS_VALUES = @(
    [Net.HttpStatusCode]::MultipleChoices.value__,  # 300
    [Net.HttpStatusCode]::MovedPermanently.value__, # 301
    [Net.HttpStatusCode]::Found.value__,            # 302
    [Net.HttpStatusCode]::SeeOther.value__,         # 303
    [Net.HttpStatusCode]::TemporaryRedirect.value__ # 307
);

function GetHttpResponse([ref]$Target, [Object]$Options) {
    # Sends a request to the last redirection if exists, otherwise, an ordinary URL
    $location = $Target.Value.Location;
    if ($location.Redirection -ne $null) {
        do {
            $location = $location.Redirection;
            $locationurl = $location.Url;
        } while ($location.Redirection -ne $null);
    } else {
        $locationurl = $location.Url;
    }
    $request = [Net.HttpWebRequest]::Create($locationurl);

    if ($Options.ProxyUrl -ne $null) {
        $proxy = New-Object System.Net.WebProxy($Options.ProxyUrl, $true);
        if ($Options.ProxyCredential -ne $null) {
            $proxy.Credentials = $Options.ProxyCredential;
        }
        $request.Proxy = $proxy;
        $connection = 'Proxy';
    } else {
        $connection = 'HTTP';
    }
    $credential = $Options.HttpCredential;
    if ($credential -ne $null) {
        $authstr = '{0}:{1}' -f $credential.UserName, $credential.Password;
        $authbytes = [Text.Encoding]::ASCII.GetBytes($authstr);
        $request.Headers.Add('Authorization', [Convert]::ToBase64String($authbytes));
        $request.PreAuthenticate = $true;
        $request.Credentials = $credential;
    }
    $offset = $Options.ContentOffset;
    if ($offset -gt 0) {
        $request.AddRange($offset);
    }
    if ($Options.IfModifiedSince -ne $null) {
        $request.IfModifiedSince = $Options.IfModifiedSince;
    }
    $Headers | ForEach-Object {
        $request.Headers.Add($_);
    }
    $request.Referer = $Options.Referer;
    $request.UserAgent = $Options.UserAgent;
    $request.CookieContainer = $Options.Cookies;
    $request.KeepAlive = $Options.HttpKeepAlive;
    $request.AllowAutoRedirect = $false;
    $request.Method = $Options.HttpMethod;
    $response = $null;

    try {
        $Logger.AppendFormat($MessageList.HTTP_REQUEST_SENT, $connection);
        $Logger.Flush();
        $response = $request.GetResponse();
        $statusval = $response.StatusCode.value__;
        $description = $response.StatusDescription;
        $Logger.AppendFormat('{0} {1}', $statusval, $description);
        $Logger.FlushLine();

        # Sets only MIME type in 'Content-Type' field into the target object
        $typematch = $HTTP_CONTENT_TYPE_REGEX.Match($response.ContentType);
        if ($typematch.Success) {
            # Adds the hash table of parameters following a media type to the target
            $parameters = GetHttpParameters $typematch.Groups[4].Captures `
                                            $typematch.Groups[5].Captures;
            $Target.Value.ContentType = $typematch.Groups[1].Value;
            $Target.Value.ContentParameters = $parameters;
        }

        if ($Options.ContentDispositonAttached) {
            # Sets a type and parameters in 'Content-Position' field into the target object
            $dispfield = $response.Headers.Get('Content-Disposition');
            $dispmatch = $HTTP_CONTENT_DISPOSITION_REGEX.Match($dispfield);
            if ($dispmatch.Success) {
                $parameters = GetHttpParameters $dispmatch.Groups[4].Captures `
                                                $dispmatch.Groups[5].Captures;
                $Target.Value.ContentDisposition = New-Object PSObject -Prop @{
                    $TARGET_CONTENT_DISPOSITION_TYPE = $dispmatch.Groups[1].Value;
                    $TARGET_CONTENT_DISPOSITION_PARAMETERS = $parameters;
                };
            }
        }

        if ($Options.Cookies -ne $null) {
            $Target.Value.Cookies = $response.Cookies;
        }
        $Target.Value.ContentOffset = $offset;
        $Target.Value.ContentLength = $response.ContentLength;
        $Target.Value.LastModified = $response.LastModified;

        if ($HTTP_REDIRECTED_STATUS_VALUES -contains $statusval) {
            # Redirects a target to URL of 'Location' field in the header
            $urlstring = $response.Headers.Get('Location');
            if ((-not [String]::IsNullOrEmpty($urlstring)) `
                -or ($statusval -ne [Net.HttpStatusCode]::MultipleChoices.value__)) {
                $redirecturl = [Uri]$urlstring;
                $location.Redirection = GetDownloadLocation $redirecturl;
                $Logger.AppendFormat($MessageList.HTTP_REDIRECTION_LOCATION, $urlstring);
                $Logger.Append($MessageList.HTTP_REDIRECTION_FOLLOWING);
                $Logger.FlushLine();
                if (-not $redirecturl.IsAbsoluteUri) {
                    $Logger.AppendFormat($MessageList.NO_SUPPORTED_URL, $urlstring);
                    $Logger.FlushLine();
                    $response.Close();
                    return $null;
                }
                $Target.Value.LocalName = GetDownloadLocalName $redirecturl $Options;
            }
        }
    } catch [Net.WebException] {
        if ($_.Exception.Status -ne [Net.WebExceptionStatus]::ProtocolError) {
            $Logger.FlushLine();
            throw;
        }
        # Fails to receive HTTP response by GetResponse for a request
        $localname = $Target.Value.LocalName;
        $statusval = $_.Exception.Response.StatusCode.value__;
        $Logger.AppendFormat('{0} {1}', $statusval, $_.Exception.Response.StatusDescription);
        $Logger.FlushLine();
        switch ($statusval) { # HTTP status codes
            ([Net.HttpStatusCode]::NotModified.value__) { # 304
                $Logger.AppendFormat($MessageList.FILE_NOT_MODIFIED, $localname);
                $Target.Value.Condition = $TARGET_CONDITION_NOT_MODIFIED;
            }
            ([Net.HttpStatusCode]::Unauthorized.value__) { # 401
                $Logger.AppendFormat($MessageList.HTTP_AUTHENTICATION_REQUIRED, 'HTTP');
                $Target.Value.Condition = $TARGET_CONDITION_NO_ACCESS;
            }
            ([Net.HttpStatusCode]::NotFound.value__) { # 404
                if ($Method -eq [Net.WebRequestMethods+Http]::Head) {
                    $Logger.Append($MessageList.REMOTE_FILE_NOT_EXIST);
                } else {
                    $Logger.AppendFormat($MessageList.FILE_NOT_FOUND, $locationurl.LocalPath);
                }
                $Target.Value.Condition = $TARGET_CONDITION_NOT_FOUND;
            }
            ([Net.HttpStatusCode]::ProxyAuthenticationRequired.value__) { # 407
                $Logger.AppendFormat($MessageList.HTTP_AUTHENTICATION_REQUIRED, 'Proxy');
                $Target.Value.Condition = $TARGET_CONDITION_NO_ACCESS;
            }
            ([Net.HttpStatusCode]::RequestedRangeNotSatisfiable.value__) { # 416
                $Logger.AppendFormat($MessageList.FILE_ARLEADY_RETRIEVED, $localname);
                $Target.Value.Condition = $TARGET_CONDITION_ARLEADY_EXISTS;
            }
            ([Net.HttpStatusCode]::GatewayTimeout.value__) { # 504
                $Logger.Append($MessageList.HTTP_GATEWAY_TIMED_OUT);
                $Target.Value.Condition = $TARGET_CONDITION_DISCONNECTED;
            }
            default {
                $Logger.AppendFormat($MessageList.HTTP_REQUEST_CLOSED, $statusval);
            }
        }
    }

    return $response;
}

# Returns a file name of 'Content-Disposition' included in the specified object.
#
# $ContentDisposition - 'Content-Disposition' object which has a type and parameters
# return a file name of 'Content-Disposition' included in the specified object if exists,
# otherwise, $null

$HTTP_CONTENT_DISPOSITION_EXT_FILENAME_REGEX = `
    [Regex]("[Uu][Tt][Ff]-?8'[^']*'({$HTTP_HEADER_CHARS})");

function GetContentDispositionFileName([Object]$ContentDisposition) {
    if (($ContentDisposition -ne $null) `
        -and ($ContentDisposition.DispositionType -eq 'attachment')) {
        $parameters = $ContentDisposition.DispositionParameters;
        $extvalue = $parameters.Item('filename*');
        $filematch = $HTTP_CONTENT_DISPOSITION_EXT_FILENAME_REGEX.Match($extvalue);
        if ($filematch.Success) {
            $filename = [Web.HttpUtility]::UrlDecode($filematch.Groups[1].Value);
        } else {
            $filename = $parameters.Item('filename');
        }
        if ($filename -is [String]) {
            return (EncodeUnusableChars $filename) -replace '%20', ' ';
        }
    }
    return $null;
}

# The progress of downloading a file which counts the byte length read from a web site
# and displays the label, percentage, bar, size, speed, and time to error console

$ProgressLabel = New-Object PSObject -Prop @{
    Name = $null;
    Width = 0;
} | Add-Member -PassThru ScriptMethod 'SetName' {
    Param([String]$name);
} | Add-Member -PassThru ScriptMethod 'ResetName' {
    $this.SetName($this.Name);
} | Add-Member -PassThru ScriptMethod 'Show' {
    Param([boolean]$finished=$false);
};

$Progress = New-Object PSObject -Prop @{
    TotalSize = [long]-1;
    Offset = [long]0;
    ByteLength = [long]0;
    IntermediateTime = $null;
    ConsoleCursorVisible = [Console]::CursorVisible;
} | Add-Member -PassThru ScriptMethod 'GetCurrentLength' {
    return $this.ByteLength - $this.Offset;
} | Add-Member -PassThru ScriptMethod 'Start' {
    Param([long]$offset, [long]$length);
    if ($length -ge 0) {
        $this.TotalSize = $offset + $length;
    } else {
        $this.TotalSize = [long]-1;
    }
    $this.Offset = $offset;
    $this.ByteLength = $offset;
    $this.IntermediateTime = Get-Date;
    [Console]::CursorVisible = $false;
} | Add-Member -PassThru ScriptMethod 'AdvanceFor' {
    Param([int]$bytelen);
    $this.ByteLength += $bytelen;
    # Displays the progress of downloading a file by refresh milliseconds
    $currenttime = Get-Date;
    $span = $currenttime - $this.IntermediateTime;
    if ($span.TotalMilliseconds -ge $PROGRESS_REFRESH_MILLISECONDS) {
        $this.IntermediateTime = $currenttime;
        $this.Refresh();
    }
} | Add-Member -PassThru ScriptMethod 'Refresh' {
    Param([boolean]$finished=$false);
} | Add-Member -PassThru ScriptMethod 'Finish' {
    if ($this.IntermediateTime -ne $null) {
        $this.IntermediateTime = $null;
        [Console]::CursorVisible = $this.ConsoleCursorVisible;
    }
};

if ($ShowProgress -or (-not $Quiet)) {
    if ($ShowMarquee) {
        # Marquee of a file name to the left on a progress bar
        $ProgressMarqueeBuffer = New-Object Text.StringBuilder($PROGRESS_LABEL_WIDTH * 2);
        $ProgressLabel `
        | Add-Member -PassThru NoteProperty 'MarqueeRemaining' 0 `
        | Add-Member -PassThru NoteProperty 'MarqueeBuffer' $ProgressMarqueeBuffer `
        | Add-Member -Force -PassThru ScriptMethod 'SetName' {
            Param([String]$name);
            $buf = $this.MarqueeBuffer;
            $this.Name = $name;
            $this.MarqueeRemaining = $name.Length;
            [void]$buf.Remove(0, $buf.Length).Append($name);
        } | Add-Member -Force ScriptMethod 'Show' {
            Param([boolean]$finished=$false);
            $buf = $this.MarqueeBuffer;
            $buf.Length = $buf.Capacity;
            if (-not $finished) {
                [Console]::ForegroundColor = $PROGRESS_LABEL_FOREGROUND_COLOR;
            }
            [Console]::Error.Write('{0} ', $buf.ToString(0, $PROGRESS_LABEL_WIDTH - 1));
            [Console]::ResetColor();
            [void]$buf.Remove(0, 1);
            $this.MarqueeRemaining--;
            if ($this.MarqueeRemaining -le 0) {
                $this.MarqueeRemaining = $buf.Capacity;
                $buf.Length = $PROGRESS_LABEL_WIDTH - 1;
                [void]$buf.Append($this.Name);
            }
        };
        $ProgressLabel.Width = $PROGRESS_LABEL_WIDTH;
    }

    # Progress bar of downloading a file, which displays the extent for a percent

    $ProgressBar = New-Object PSObject -Prop @{
        Extent = 0;
        ExtentRate = 0.0;
        ExtentBuffer = $null;
        ExtentAdjustable = $false;
    } | Add-Member -PassThru ScriptMethod 'Init' {
        Param([int]$capacity, [double]$percentage);
        $buf = New-Object Text.StringBuilder $capacity;
        $this.Extent = 0;
        $this.ExtentRate = 100 / $capacity;
        $this.ExtentBuffer = $buf;
        $this.ExtentAdjustable = $true;
        if ($percentage -lt 0.0) {
            # Sets unchanged characters into the buffer of a progress bar
            $this.ExtentAdjustable = $false;
            [void]$buf.Append(' <=');
        } elseif ($percentage -gt 0.0) {
            $this.Change($percentage);
            [void]$buf.Append('+', $this.Extent);
        }
        [void]$buf.Append('>');
    } | Add-Member -PassThru ScriptMethod 'Change' {
        Param([double]$percentage);
        if ($this.ExtentAdjustable) {
            $extent = [Math]::Floor($percentage / $this.ExtentRate);
            $capacity = $this.ExtentBuffer.Capacity;
            if ($extent -ge $capacity) { # Filled buffer except for '>'
                $extent = $capacity - 1;
                $this.ExtentAdjustable = $false;
            }
            $this.Extent = $extent;
        }
    } | Add-Member -PassThru ScriptMethod 'Show' {
        Param([boolean]$finished=$false);
        $buf = $this.ExtentBuffer;
        if ($buf.Length -le $this.Extent) {
            $buf.Length--;
            [void]$buf.Append('=', ($this.Extent - $buf.Length)).Append('>');
        }
        $buf.Length = $buf.Capacity;
        if ($finished) {
            [Console]::ForegroundColor = $PROGRESS_BAR_FOREGROUND_FINISHED_COLOR;
        } else {
            [Console]::ForegroundColor = $PROGRESS_BAR_FOREGROUND_ADVANCED_COLOR;
        }
        [Console]::BackgroundColor = $PROGRESS_BAR_BACKGROUND_COLOR;
        [Console]::Error.Write('[{0}]', $buf.ToString());
        [Console]::ResetColor();
        $buf.Length = $this.Extent + 1;
    };

    # Control and view of a download progress

    $ProgressTimeBlinkingSecconds = [double]((ParseMilliseconds $BlinkingTime) / 1000);
    if ($ProgressTimeBlinkingSecconds -lt 0) {
        Write-Error ($MessageList.NOT_CHANGED_TO_VALUE -f $BlinkingTime) -Category SyntaxError;
        exit 1;
    }
    $Progress `
    | Add-Member -PassThru NoteProperty 'StartTime' $null `
    | Add-Member -PassThru NoteProperty 'EndTime' $null `
    | Add-Member -PassThru NoteProperty 'TimeBlinkingCount' $null `
    | Add-Member -PassThru -Force ScriptMethod 'Start' {
        Param([long]$offset, [long]$length);
        $barlimit = $PROGRESS_BAR_LIMIT - $ProgressLabel.Width;
        if ($length -ge 0) {
            $total = $offset + $length;
            $percentage = $offset / $total * 100;
        } else {
            $total = -1;
            $percentage = -1.0;
        }
        $ProgressBar.Init($barlimit, $percentage);
        $this.TotalSize = $total;
        $this.Offset = $offset;
        $this.ByteLength = $offset;
        [Console]::CursorVisible = $false;
        if ((-not $Quiet) -and ($OutputFile -eq "")) {
            [Console]::Error.WriteLine();
        }
        $this.StartTime = Get-Date;
        $this.EndTime = $null;
        $this.IntermediateTime = $null;
        $this.TimeBlinkingCount = 0;
        $this.Refresh();
    } | Add-Member -PassThru -Force ScriptMethod 'Refresh' {
        Param([boolean]$finished=$false);
        # Displays a download size in any time, and others by conditions
        $percent = @("", "");
        $percentage = 0.0;
        $bytelen = $this.ByteLength;
        $size = ToUnitByteString $bytelen @(2, 2, 2, 1);
        $speed = '--.-K';
        $timefmt = '{0,15}';
        $time = "";
        $timespan = $null;
        $timedecimalplaces = $null;
        $timecolor = [Console]::ForegroundColor;
        $total = $this.TotalSize;
        if ($total -gt 0) {
            # Displays a download percent and others if the total size is specified
            $percentage = $bytelen / $total * 100;
            $ProgressBar.Change($percentage);
            $percent[0] = [Math]::Floor($percentage);
            $percent[1] = '%';
            if ($this.IntermediateTime -ne $null) {
                # Displays a download speed and others if finished or not the first time
                $span = $this.IntermediateTime - $this.StartTime;
                $bytepersec = ($bytelen - $this.Offset) / $span.TotalMilliseconds * 1000;
                $speed = ToUnitByteString $bytepersec @(2, 1);
                if ($finished) {  # The amount of a download time
                    $timefmt = $MessageList.PROGRESS_TIME_FIELD;
                    $timespan = $span;
                    $timedecimalplaces = @(1);
                } else { # Estimated time of arrival
                    $remaining = $total - $bytelen;
                    if ($bytepersec -gt ($remaining / [int]::MaxValue)) {
                        $timefmt = $MessageList.PROGRESS_ETA_FIELD;
                        $timeseconds = $remaining / $bytepersec;
                        if ($timeseconds -lt $ProgressTimeBlinkingSecconds) {
                            # Blinks ETA less than a seconds by -BlinkingTime
                            $this.TimeBlinkingCount++;
                            if ($this.TimeBlinkingCount % 2) {
                                $timecolor = $PROGRESS_TIME_BLINKING_COLOR;
                            }
                        }
                        $timespan = New-TimeSpan -Seconds ([int]$timeseconds);
                    }
                }
            } else {
                $this.IntermediateTime = $this.StartTime;
            }
        } elseif ($finished) {  # The amount of a download time
            $timefmt = $MessageList.PROGRESS_TIME_FIELD;
            $timespan = $this.EndTime - $this.StartTime;
            $timedecimalplaces = @(1);
        } else {
            $this.IntermediateTime = $this.StartTime;
        }
        if ($timespan -ne $null) {
            # Displays the amount if finished, or ETA if the total size is specified
            $time = ToUnitTimeString $timespan 1 1 $timedecimalplaces;
        }
        # Writes strings created by a downloading state to the progress bar
        [Console]::CursorLeft = 0;
        $ProgressLabel.Show($finished);
        [Console]::Error.Write('{0,3}{1,1}', $percent);
        $ProgressBar.Show($finished);
        [Console]::Error.Write(' {0,7}', $size);
        [Console]::Error.Write(' {0,6}B/s', $speed);
        [Console]::ForegroundColor = $timecolor;
        [Console]::Error.Write($timefmt, $time);
        [Console]::ResetColor();
    } | Add-Member -Force ScriptMethod 'Finish' {
        if ($this.StartTime -ne $null) {
            $this.EndTime = Get-Date;
            $this.IntermediateTime = $this.EndTime;
            $this.Refresh($true);
            $this.StartTime = $null;
            [Console]::Error.WriteLine();
            if ((-not $Quiet) -and ($OutputFile -eq "")) {
                [Console]::Error.WriteLine();
            }
            [Console]::CursorVisible = $this.ConsoleCursorVisible;
        }
    };
}

# Environment for downloading all targets

if ($Directory -ne "") {
    $dirobj = Get-Item $Directory 2> $null;
    if ((-not $?) -or (-not $dirobj.PSIsContainer)) {
        New-Item $Directory -ItemType Directory > $null;
        if (-not $?) {
            exit 1;
        }
    }
}

$DownloadEnv = New-Object PSObject -Prop @{
    DirectoryReference = $Directory -replace '\\', '/' -replace '[^/]$', '$&/';
    DirectoryDestination = (Resolve-Path ($Directory -replace '^$', '.')).Path + '\';
    TargetFailureDisposed = $Dispose;
    TargetNotSaved = $Spider;
    TargetRemainingCanceled = $false;
    QuotaByteLength = [long]::MaxValue;
} | Add-Member -PassThru ScriptMethod 'GetReferencePath' {
    Param([String]$localname);
    return $this.DirectoryReference + $localname;
} | Add-Member -PassThru ScriptMethod 'GetDestinationPath' {
    Param([String]$localname);
    return $this.DirectoryDestination + $localname;
};

if ($Quota -ne "") {
    $DownloadEnv.QuotaByteLength = ParseByteLength $Quota;
    if ($DownloadEnv.QuotaByteLength -lt 0) {
        Write-Error ($MessageList.NOT_CHANGED_TO_VALUE -f $Quota) -Category SyntaxError;
        exit 1;
    }
}

# Writes byte data read from the response to a local file for the specified target.
#
# $Target - the object of a download target
# $Response - a FTP or HTTP response

function DownloadFile([ref]$Target, [Net.WebResponse]$Response) {
    $localname = $Target.Value.LocalName;
    $localpath = $DownloadEnv.GetDestinationPath($localname);
    $offset = $Target.Value.ContentOffset;
    $length = $Target.Value.ContentLength;
    if ($offset -gt 0) {
        $writemode = [IO.FileMode]::Append;
    } else {
        $writemode = [IO.FileMode]::Create;
    }
    $writer = $null;
    $stream = $null;

    # Displays the information of download contents on FTP or HTTP server

    if ($length -ge 0) {
        $total = $offset + $length;
        $totalstr = $total.ToString();
    } else {
        $total = -1;
        $totalstr = $MessageList.CONTENT_LENGTH_UNSPECIFIED;
    }

    $Logger.AppendFormat($MessageList.CONTENT_LENGTH, $totalstr);
    if ($total -ge $UNIT_BYTE_LENGTH) {
        $Logger.AppendByteLength(' ({0})', $total);
    }
    if ($offset -gt 0) {
        $Logger.AppendFormat(', {0}', $length);
        if ($length -ge $UNIT_BYTE_LENGTH) {
            $Logger.AppendByteLength(' ({0})', $length);
        }
        $Logger.Append($MessageList.CONTENT_LENGTH_REMAINING);
    }
    $Logger.AppendValidFormat(' [{0}]', $Target.Value.ContentType,
                              $MessageList.CONTENT_TYPE_UNAUTHORITATIVE);
    $Logger.FlushLine();
    if ($DownloadEnv.TargetNotSaved) {
        # Finishes to check file exiting for a HTTP request if -Spider specified
        $Logger.Append($MessageList.REMOTE_FILE_EXISTS);
        return;
    }
    $Logger.AppendFormat($MessageList.CONTENT_SAVING_TO,
                         $DownloadEnv.GetReferencePath($localname));
    $Logger.FlushLine();

    try {
        if ($Host.UI.RawUI.KeyAvailable `
            -and ($key = $Host.UI.RawUI.ReadKey('AllowCtrlC,NoEcho,IncludeKeyUp'))) {
            if ([int]$key.Character -eq 3) {
                $DownloadEnv.TargetRemainingCanceled = $true;
                throw New-Object IO.IOException;
            }
            $Host.UI.RawUI.FlushInputBuffer();
        }

        # Writes byte data read from the response stream to a local file

        $ProgressLabel.SetName($localname);
        $Progress.Start($offset, $length);

        $stream = $Response.GetResponseStream();
        $readbuf = New-Object byte[] $DOWNLOAD_BUFFER_SIZE;
        $readcontinued = $true;
        $writer = New-Object IO.FileStream($localpath, $writemode, [IO.FileAccess]::Write);
        $writecompleted = $false;

        do {
            $readlen = $stream.Read($readbuf, 0, $readbuf.Length);
            if ($readlen -le 0) {
                break;
            } elseif ($readlen -gt $DownloadEnv.QuotaByteLength) {
                # Exits this loops if byte data read from a response is over quota size
                $readlen = $DownloadEnv.QuotaByteLength;
                $readcontinued = $false;
                $DownloadEnv.QuotaByteLength = -1;
            } else {
                # Continues reading byte data once more if the same, otherwise, ordinarily
                $DownloadEnv.QuotaByteLength -= $readlen;
            }

            $writer.Write($readbuf, 0, $readlen);
            $Progress.AdvanceFor($readlen);

            if ($Host.UI.RawUI.KeyAvailable `
                -and ($key = $Host.UI.RawUI.ReadKey('AllowCtrlC,NoEcho,IncludeKeyUp'))) {
                if ([int]$key.Character -eq 3) {
                    $DownloadEnv.TargetRemainingCanceled = $true;
                    throw New-Object IO.IOException;
                }
                $Host.UI.RawUI.FlushInputBuffer();
            }
        } while ($readcontinued);

        if ($DownloadEnv.QuotaByteLength -le 0) {
            $DownloadEnv.TargetRemainingCanceled = $true;
        }
        $writecompleted = $true;
    } catch [Net.WebException] {
        if ($_.Exception.Status -ne [Net.WebExceptionStatus]::ProtocolError) {
            throw;
        }
        # Fails to read byte data from FTP or HTTP connection
        $location = $Target.Value.Location;
        $statusval = $exception.Response.StatusCode.value__;
        if ($TARGET_URL_FTP_SCHEMES -contains $location.Url.Scheme) {
            if ($FTP_CONNECTION_DISCONNECTED_STATUS_VALUES -contains $statusval) {
                $Logger.Append($MessageList.CONNECTION_ERROR_OCCURS);
                $Target.Value.Condition = $TARGET_CONDITION_DISCONNECTED;
            } else {
                $Logger.Append($MessageList.FTP_ACTION_NOT_TAKE_PLACE);
            }
        } elseif ($statusval -eq [Net.HttpStatusCode]::GatewayTimeout.value__) { # 504
            $Logger.Append($MessageList.HTTP_GATEWAY_TIMED_OUT);
            $Target.Value.Condition = $TARGET_CONDITION_DISCONNECTED;
        } else {
            $Logger.AppendFormat($MessageList.HTTP_REQUEST_CLOSED, $statusval);
        }
    } catch [IO.IOException] {
        # Interrupts writing byte data to a local file
        if ($DownloadEnv.TargetRemainingCanceled) {
            $writingmsg = $MessageList.SUSPEND_WRITING_TO;
        } else {
            $writingmsg = $MessageList.CANNOT_WRITE_TO;
        }
        $Logger.AppendFormat($writingmsg, $DownloadEnv.GetReferencePath($localname));
        $Target.Value.Condition = $TARGET_CONDITION_ABORTED;
    } finally {
        try {
            if ($stream -ne $null) {
                $stream.Close();
            }
        } catch [Net.WebException] {
        }
        if ($writer -ne $null) {
            $writer.Flush();
            $writer.Close();

            if ($writecompleted) {
                # Adapts the file name or timestamp on server for a local file
                $filename = GetContentDispositionFileName $Target.Value.ContentDisposition;
                if ($filename -ne $null) {
                    Rename-Item $localpath $filename 2> $null;
                    if ($?) {
                        $localname = $filename;
                        $Target.Value.LocalName = $localname;
                    }
                }
                $localobj = Get-Item $DownloadEnv.GetDestinationPath($localname);
                $localobj.LastWriteTime = $Target.Value.LastModified;

                if ($DownloadEnv.QuotaByteLength -ge 0) {
                    $savingmsg = $MessageList.FILE_SAVED;
                } else {
                    $savingmsg = $MessageList.QUOTA_EXCEEDED_BY;
                }
                $Logger.AppendFormat($savingmsg, $DownloadEnv.GetReferencePath($localname));
                $Target.Value.Condition = $TARGET_CONDITION_COMPLETED;
            } elseif ($DownloadEnv.TargetFailureDisposed) {
                # Removes a file which is not downloaded completely if -Dispose specified
                Remove-Item $localpath 2> $null;
            }

            $Target.Value.ByteLength = $Progress.GetCurrentLength();
            $ProgressLabel.ResetName();
        }
        $Progress.Finish();
    }
}

$CONNECTION_ERROR_STATUS_VALUES = @(
    [Net.WebExceptionStatus]::ConnectFailure.value__,       # 2
    [Net.WebExceptionStatus]::PipelineFailure.value__,      # 5
    [Net.WebExceptionStatus]::ConnectionClosed.value__,     # 8
    [Net.WebExceptionStatus]::SecureChannelFailure.value__, # 10
    [Net.WebExceptionStatus]::KeepAliveFailure.value__      # 12
);

$CONNECTION_TIMED_OUT_STATUS_VALUES = @(
    [Net.WebExceptionStatus]::Pending.value__, # 13
    [Net.WebExceptionStatus]::Timeout.value__  # 14
);

$DownloadConnectTimeout = ParseMilliseconds $ConnectTimeout;
if ($DownloadConnectTimeout -lt 0) {
    Write-Error ($MessageList.NOT_CHANGED_TO_VALUE -f $ConnectTimeout) -Category SyntaxError;
    exit 1;
}

$DownloadStartPosition = ParseByteLength $StartPos;
if ($DownloadStartPosition -gt 0) {
    # Doesn't resume downloading files
    $Continue = $false;
} elseif ($DownloadStartPosition -lt 0) {
    Write-Error ($MessageList.NOT_CHANGED_TO_VALUE -f $StartPos) -Category SyntaxError;
    exit 1;
}

# FTP download options

if ($NoPassiveFtp) {
    $DownloadFtpTransferMode = 'PORT';
} else {
    $DownloadFtpTransferMode = 'PASV';
}
$DownloadFtpCredential = New-Object Net.NetworkCredential($FtpUser, $FtpPassword);

# HTTP download options

$DownloadHttpMethod = [Net.WebRequestMethods+Http]::Get;
$DownloadHttpCredential = $null;
$DownloadProxyCredential = $null;
$DownloadProxyUrl = $null;
if ($Spider) {
    $DownloadHttpMethod = [Net.WebRequestMethods+Http]::Head;
}
if ($HttpUser -ne "") {
    $DownloadHttpCredential = New-Object Net.NetworkCredential($HttpUser, $HttpPassword);
}
if ($HttpProxy -is [Uri]) {
    if (-not $HttpProxy.IsAbsoluteUri) {
        Write-Error ($MessageList.NO_SUPPORTED_URL -f $HttpProxy.OriginalString) `
                     -Category SyntaxError;
        exit 1;
    }
    if ($ProxyUser -ne "") {
        $DownloadProxyCredential = New-Object Net.NetworkCredential($ProxyUser, $ProxyPassword);
    }
    $DownloadProxyUrl = $HttpProxy;
}
if ((EncodeUnusableChars $DefaultPage) -ne $DefaultPage) {
    Write-Error ($MessageList.UNUSABLE_CHARS_INCLUDED -f $DefaultPage) -Category SyntaxError;
    exit 1;
}

# Starts downloading for URLs specified on command line or read from a input file

if ($InputFile -ne "") {
    $UrlList += Get-Content $InputFile -Encoding UTF8 `
                | Where-Object {
                    $_ -notmatch "^[`t ]*(#|$)";
                };
}
if ($UrlList.Length -eq 0) {
    exit;
}
try {
    if ($OutputFile -ne "") {
        $outobj = Get-Item $OutputFile 2> $null;
        if ((-not $?) -or $outobj.PSIsContainer) {
            New-Item $OutputFile -ItemType File > $null;
            if (-not $?) {
                exit 1;
            }
        }
        $Logger.Open($outobj.FullName, $OutputAppend);
    } elseif (-not $Quiet) {
        $Logger.Open();
    }

    # Loops the target object created for each URL in a list

    $urlcount = 0;
    do {
        $targeturl = $UrlList[$urlcount];
        $targetopts = New-Object PSObject -Prop @{
            Timeout = $DownloadConnectTimeout
            FtpTransferMode = $DownloadFtpTransferMode;
            FtpCredential = $DownloadFtpCredential;
            HttpMethod = $DownloadHttpMethod;
            HttpCredential = $DownloadHttpCredential;
            HttpKeepAlive = -not $NoHttpKeepAlive;
            ProxyUrl = $DownloadProxyUrl;
            ProxyCredential = $DownloadProxyCredential;
            ContentOffset = $DownloadStartPosition;
            IfModifiedSince = $null;
            Headers = $Headers;
            UserAgent = $UserAgent;
            Referer = $Referer;
            Cookies = $Cookies;
            DefaultPage = $DefaultPage;
            QueryAppendExtensions = $QueryAppendExtensions;
            ContentDispositonAttached = $ContentDisposition;
        };
        $target = GetDownloadTarget $targeturl $targetopts;
        if ($target -eq $null) {
            Write-Error ($MessageList.NO_SUPPORTED_URL -f $targeturl.OriginalString) `
                        -Category SyntaxError;
            $urlcount++;
            continue;
        }
        $location = $target.Location;
        $localname = $target.LocalName;
        $localnoproblem = $true;
        $starttime = Get-Date;
        $endtime = $null;

        $Logger.Append($location.Url.AbsoluteUri);
        $Logger.Announce('--yyyy-MM-dd HH:mm:ss--', $starttime);

        if (-not $Spider) {

            # Gets the size or timestamp of a downloaded file on the local

            if ($localname -ne $null) {
                $localpath = $DownloadEnv.GetDestinationPath($localname);
                if ([IO.Directory]::Exists($localpath)) {
                    $Logger.AppendFormat($MessageList.FILE_ARLEADY_EXISTS, $localpath);
                    $target.Condition = $TARGET_CONDITION_ARLEADY_EXISTS;
                    $localnoproblem = $false;
                }
                $localobj = Get-Item $localpath 2> $null;
                if ($localobj -is [IO.FileInfo]) {
                    if ($Continue) {
                        $targetopts.ContentOffset = $localobj.Length;
                    } elseif ($Newer) {
                        $targetopts.IfModifiedSince = $localobj.LastWriteTime;
                    } elseif ($NoClobber) {
                        $Logger.AppendFormat($MessageList.FILE_ARLEADY_EXISTS, $localpath);
                        $target.Condition = $TARGET_CONDITION_ARLEADY_EXISTS;
                        $localnoproblem = $false;
                    }
                }
            }
        }

        if ($localnoproblem) {
            if (($HttpProxy -eq $null) `
                -or ($TARGET_URL_FTP_SCHEMES -contains $location.Url.Scheme)) {
                $connecturl = $location.Url;
            } else {
                $connecturl = $HttpProxy;
            }
            $response = $null;

            try {
                [Console]::TreatControlCAsInput = $true;
                Start-Sleep -Milliseconds 1000;
                $Host.UI.RawUI.FlushInputBuffer();

                # Resolves a host name, sends a FTP or HTTP request, and receives a response

                if (ResolveHostName $connecturl) {
                    if ($TARGET_URL_FTP_SCHEMES -contains $location.Url.Scheme) {
                        $response = GetFtpResponse ([ref]$target) $targetopts;
                        if ($response -ne $null) {
                            if ($target.DirectoryList -is [Object[]]) {
                                # Lists the information of files in a FTP directory
                                ReadFtpDirectoryList ([ref]$target) $response;
                            } elseif (-not $Spider) {
                                DownloadFile ([ref]$target) $response;
                            } else {
                                $Logger.Append($MessageList.REMOTE_FILE_EXISTS);
                            }
                        }
                    } else {

                        # Continues sending requests for a HTTP target until no redirection

                        $redirect = 0;
                        do {
                            $response = GetHttpResponse ([ref]$target) $targetopts;
                            if ($location.Redirection -eq $null) {
                                if ($response -ne $null) {
                                    DownloadFile ([ref]$target) $response;
                                }
                                break;
                            }
                            $redirect++;
                            if ($redirect -gt $MaxRedirect) {
                                $Logger.Append($MessageList.HTTP_REDIRECTION_EXCEEDED);
                                $target.Condition = $TARGET_CONDITION_REDIRECTED;
                                break;
                            }
                            $location = $location.Redirection;
                            $Logger.Append($location.Url.AbsoluteUri);
                            $Logger.Announce('--yyyy-MM-dd HH:mm:ss--', (Get-Date));

                            if ($HttpProxy -eq $null) {
                                $connecturl = $location.Url;
                            }
                        } while (ResolveHostName $connecturl);
                    }
                }
            } catch [Net.WebException] {
                # Fails a connection or transmission undering FTP or HTTP session
                $statusval = $_.Exception.Status.value__;
                if ($CONNECTION_ERROR_STATUS_VALUES -contains $statusval) {
                    $Logger.Append($MessageList.CONNECTION_ERROR_OCCURRED);
                    $target.Condition = $TARGET_CONDITION_DISCONNECTED;
                } elseif ($CONNECTION_TIMED_OUT_STATUS_VALUES -contains $statusval) {
                    $Logger.Append($MessageList.CONNECTION_TIMED_OUT);
                    $target.Condition = $TARGET_CONDITION_DISCONNECTED;
                } else {
                    $Logger.Append($MessageList.DATA_TRANSFER_FAILED);
                }
            } finally {
                if ($response -ne $null) {
                    $response.Close();
                }
                [Console]::TreatControlCAsInput = $false;
            }
        }

        $endtime = Get-Date;
        $target | Add-Member -PassThru NoteProperty $TARGET_START_TIME $starttime `
                | Add-Member NoteProperty $TARGET_END_TIME $endtime;
        $Logger.Announce($DownloadCulture.DateTimeFormat.FullDateTimePattern, $endtime);
        $Logger.FlushLine();

        if ($Verbose) {
            # Outputs the infomation object for each download target
            $target;
        }

        $urlcount++;
    } while (($urlcount -lt $UrlList.Length) `
             -and (-not $DownloadEnv.TargetRemainingCanceled));
} finally {
    $Logger.Close();
}
