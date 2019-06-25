# English messages displayed by 'EvokeRequest.ps1'.
# Copyright(C) 2019 Yoshinori Kawagita

@{
    # Error messages for the option specification

    NO_SUPPORTED_URL = "No supported URL '{0}'.";
    NOT_CHANGED_TO_VALUE = "'{0}' are not changed to a value.";
    UNUSABLE_CHARS_INCLUDED = "Unusable characters are included in '{0}'.";

    # Messages for resolving or connecting to URL's site

    RESOLVING_HOST_ADDRESS = 'Resolving {0} ({1})... ';
    RESOLVING_FAILED = 'failed.';
    REUSING_HOST_ADDRESS = 'Reusing existing connection to {0}:{1}.';
    CONNECTING_TO_HOST_ADDRESS = 'Connecting to {0}:{1}... ';
    CONNECTING_TO_IPV6_ADDRESS = 'Connecting to [{0}]:{1}... ';
    UNABLE_TO_RESOLVE_HOST_ADDRESS = "Unable to resolve host address '{0}'.";

    # Messages for FTP request

    FTP_LOGGING_IN_AS = 'Logging in as {0} ... ';
    FTP_LOGGED_IN = 'Logged in.';
    FTP_LOGIN_INCORRECT = 'incorrect.';
    FTP_LOGIN_NEEDED = 'Server needs login with USER and PASS.';
    FTP_COMMAND_DONE = 'done.';
    FTP_DIRECTORY_LISTED = 'FTP directory listed to output object.';
    FTP_DIRECTORY_NOT_FOUND = "No such FTP directory '{0}'.";
    FTP_ACTION_NOT_TAKE_PLACE = 'FTP action did not take place.';

    # Messages for HTTP request

    HTTP_REQUEST_SENT = '{0} request sent, awaiting response... ';
    HTTP_REDIRECTION_LOCATION = 'Location: {0}';
    HTTP_REDIRECTION_FOLLOWING = ' [following]';
    HTTP_REDIRECTION_EXCEEDED = 'Redirections exceeded.';
    HTTP_AUTHENTICATION_REQUIRED = '{0} authentication required.';
    HTTP_GATEWAY_TIMED_OUT = 'Gateway timed out.';
    HTTP_REQUEST_CLOSED = 'HTTP request closed by {0} error.';

    # Messages for FTP and HTTP connection

    CONNECTION_ERROR_OCCURRED = 'Connection error occurred.';
    CONNECTION_TIMED_OUT = 'Connection timed out.';
    DATA_TRANSFER_FAILED = 'Data transfer failed.';

    # Messages for downloaded contents

    CONTENT_LENGTH = 'Length: {0}';
    CONTENT_LENGTH_UNSPECIFIED = 'unspecified';
    CONTENT_LENGTH_REMAINING = ' remaining';
    CONTENT_TYPE_UNAUTHORITATIVE = ' (unauthoritative)';
    CONTENT_SAVING_TO = "Saving to: '{0}'";

    # Fields on the progress bar

    PROGRESS_ETA_FIELD = '    eta {0,-7}';
    PROGRESS_TIME_FIELD = '    in {0,-8}';

    # Messages for downloaded files

    FILE_SAVED = "'{0}' saved.";
    FILE_ARLEADY_EXISTS = "'{0}' already exists.";
    FILE_NOT_FOUND = "No such file '{0}'.";
    FILE_NOT_MODIFIED = "'{0}' not modified on server.";
    FILE_ARLEADY_RETRIEVED = "'{0}' already retrieved.";
    QUOTA_EXCEEDED_BY = "Quota exceeded by '{0}'.";
    SUSPEND_WRITING_TO = "Suspend writing to '{0}'.";
    CANNOT_WRITE_TO = "Cannot write to '{0}'.";
    REMOTE_FILE_EXISTS = 'Remote file exists.';
    REMOTE_FILE_NOT_EXIST = 'Remote file does not exist.';
}
