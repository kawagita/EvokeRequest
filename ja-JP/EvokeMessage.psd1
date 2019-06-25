# Japanese messages displayed by 'EvokeRequest.ps1'.
# Copyright(C) 2019 Yoshinori Kawagita

@{
    # Error messages for the option specification

    NO_SUPPORTED_URL = "'{0}' はサポートされないURLです。";
    NOT_CHANGED_TO_VALUE = "'{0}' は値に変換できません。";
    UNUSABLE_CHARS_INCLUDED = "'{0}' は使えない文字が含まれています。";

    # Messages for resolving or connecting to URL's site

    RESOLVING_HOST_ADDRESS = 'ホスト名 {0} ({1}) のIPアドレスを調べています... ';
    RESOLVING_FAILED = '失敗しました。';
    REUSING_HOST_ADDRESS = 'すでにIPアドレスを解決した {0}:{1} へ再び接続します。';
    CONNECTING_TO_HOST_ADDRESS = '{0}:{1} へ接続しています... ';
    CONNECTING_TO_IPV6_ADDRESS = '[{0}]:{1} へ接続しています... ';
    UNABLE_TO_RESOLVE_HOST_ADDRESS = "'{0}' のIPアドレスが解決できません。";

    # Messages for FTP request

    FTP_LOGGING_IN_AS = 'ユーザ {0} でログインします ... ';
    FTP_LOGGED_IN = '成功しました。';
    FTP_LOGIN_INCORRECT = '正しくありません。';
    FTP_LOGIN_NEEDED = 'ユーザ名とパスワードによるログインを必要としています。';
    FTP_COMMAND_DONE = '完了しました。';
    FTP_DIRECTORY_LISTED = "FTP ディレクトリは出力オブジェクトにリスト化しました。";
    FTP_DIRECTORY_NOT_FOUND = "FTP ディレクトリ '{0}' は存在しません。";
    FTP_ACTION_NOT_TAKE_PLACE = 'FTP アクションは実行されませんでした。';

    # Messages for HTTP request

    HTTP_REQUEST_SENT = '{0} リクエストを送信しました。レスポンスを待っています ... ';
    HTTP_REDIRECTION_LOCATION = '転送URL: {0}';
    HTTP_REDIRECTION_FOLLOWING = ' [続行]';
    HTTP_REDIRECTION_EXCEEDED = 'リダイレクションが指定回数を超えました。';
    HTTP_AUTHENTICATION_REQUIRED = '{0} で認証が要求されました。';
    HTTP_GATEWAY_TIMED_OUT = 'ゲートウェイでタイムアウトしました。';
    HTTP_REQUEST_CLOSED = 'HTTP リクエストは {0} エラーで終了しました。';

    # Messages for FTP and HTTP connection

    CONNECTION_ERROR_OCCURRED = '接続エラーが発生しました。';
    CONNECTION_TIMED_OUT = '接続はタイムアウトになりました。';
    DATA_TRANSFER_FAILED = 'データ転送に失敗しました。';

    # Messages for downloaded contents

    CONTENT_LENGTH = 'ファイルサイズ: {0}';
    CONTENT_LENGTH_UNSPECIFIED = '未指定';
    CONTENT_LENGTH_REMAINING = ' 残りです';
    CONTENT_TYPE_UNAUTHORITATIVE = ' (内容は不明)';
    CONTENT_SAVING_TO = "保存先: '{0}'";

    # Fields on the progress bar

    PROGRESS_ETA_FIELD = '   残り {0,-7}';
    PROGRESS_TIME_FIELD = '   終了 {0,-7}';

    # Messages for downloaded files

    FILE_SAVED = "'{0}' は保存されました。";
    FILE_ARLEADY_EXISTS = "'{0}' はすでに存在しています。";
    FILE_NOT_FOUND = "ファイル '{0}' は見つかりません。";
    FILE_NOT_MODIFIED = "サーバーの '{0}' は更新されていません。";
    FILE_ARLEADY_RETRIEVED = "'{0}' はすでに回収されています。";
    QUOTA_EXCEEDED_BY = "'{0}' によって割り当てバイト長を超過しました。";
    SUSPEND_WRITING_TO = "'{0}' への書き込みを中止します。";
    CANNOT_WRITE_TO = "'{0}' への書き込みができません。";
    REMOTE_FILE_EXISTS = 'リモートファイルは存在します。';
    REMOTE_FILE_NOT_EXIST = 'リモートファイルは存在しません。';
}
