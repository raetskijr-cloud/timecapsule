<?php
// Check of the S3 storage module without the web UI (no login needed). Run it on the app server,
// where the instance role gives the permissions:  php scripts/storage-smoke.php
// It uploads a small test file, prints the headers S3 sends for the presigned link, deletes the file.

require dirname(__DIR__) . '/src/bootstrap.php';

function out(string $text): void { echo $text . PHP_EOL; }
function head(string $url): array
{
    $ctx = stream_context_create(['http' => ['method' => 'GET', 'header' => "Range: bytes=0-0\r\n", 'ignore_errors' => true]]);
    @file_get_contents($url, false, $ctx);
    return $http_response_header ?? [];
}

// Without arguments: a tiny generated PDF that is deleted at the end.
// With a path:  php scripts/storage-smoke.php /tmp/picture.png  -> the file is uploaded and KEPT.
$keep = isset($argv[1]);
$ext = $keep ? pathinfo($argv[1], PATHINFO_EXTENSION) : 'pdf';
$tmp = $keep ? $argv[1] : tempnam(sys_get_temp_dir(), 'tc');
if (!$keep) {
    file_put_contents($tmp, "%PDF-1.4\nsmoke test\n");
}
$stored = storage_save(['tmp_name' => $tmp], $ext);
if (!$keep) {
    unlink($tmp);
}
out('saved      : ' . storage_key($stored));

$url = storage_url($stored, 'application/pdf', 'Отчёт smoke.pdf', 'attachment');
out('url host   : ' . parse_url($url, PHP_URL_HOST));
out('url path   : ' . parse_url($url, PHP_URL_PATH));
out('url params : ' . implode(', ', array_map(fn($p) => explode('=', $p)[0], explode('&', (string) parse_url($url, PHP_URL_QUERY)))));
foreach (head($url) as $h) {
    if (preg_match('/^(HTTP|Content-Type|Content-Disposition)/i', $h)) {
        out('S3 says    : ' . $h);
    }
}

if ($keep) {
    out('kept       : ' . storage_key($stored));
    exit(0);
}
storage_delete($stored);
out('deleted    : ' . storage_key($stored) . ' (delete marker)');
