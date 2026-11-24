<?php
// File storage for capsule attachments: Amazon S3.
//
// This is the only file that talks to the storage. The rest of the app uses the three functions
// storage_save(), storage_delete() and storage_stream(). Files live in the bucket S3_BUCKET under
// the prefix "uploads/"; the browser downloads them straight from S3 by a presigned URL.
// AWS credentials are NOT in .env: the SDK takes the temporary keys of the instance role.

use Aws\S3\S3Client;

/**
 * Name of the bucket from .env (S3_BUCKET).
 */
function storage_bucket(): string
{
    $bucket = config('S3_BUCKET');
    if ($bucket === null) {
        throw new RuntimeException('S3_BUCKET is not set in .env');
    }
    return $bucket;
}

/**
 * The S3 client. It is created on the first call and reused later in the same request.
 */
function storage_client(): S3Client
{
    static $client = null;
    if ($client === null) {
        $client = new S3Client([
            'region'  => config('AWS_REGION', 'eu-central-1'),
            'version' => '2006-03-01',
        ]);
    }
    return $client;
}

/**
 * Lifetime of a download link in seconds (PRESIGN_TTL_SECONDS, 300 by default).
 */
function storage_link_ttl(): int
{
    return config_int('PRESIGN_TTL_SECONDS', 300);
}

/**
 * A new random stored name: 32 hex characters and the extension, e.g. "3f9a...e1.png".
 * Users cannot guess the names of other people's files.
 */
function storage_new_name(string $extension): string
{
    return bin2hex(random_bytes(16)) . '.' . $extension;
}

/**
 * The object key of a stored name. basename() keeps a damaged value out of other prefixes.
 */
function storage_key(string $storedName): string
{
    return 'uploads/' . basename($storedName);
}

/**
 * Upload a file from $_FILES to S3 and return its stored name.
 *
 * @param array  $uploadedFile an entry of $_FILES (tmp_name is used)
 * @param string $extension    extension without the dot
 */
function storage_save(array $uploadedFile, string $extension): string
{
    $storedName = storage_new_name($extension);

    storage_client()->putObject([
        'Bucket'     => storage_bucket(),
        'Key'        => storage_key($storedName),
        'SourceFile' => $uploadedFile['tmp_name'],
        'ContentType' => mime_content_type($uploadedFile['tmp_name']) ?: 'application/octet-stream',
    ]);
    return $storedName;
}

/**
 * Delete the object of a capsule. With bucket versioning this adds a delete marker; older versions stay.
 */
function storage_delete(?string $storedName): void
{
    if ($storedName === null || $storedName === '') {
        return;
    }

    storage_client()->deleteObject([
        'Bucket' => storage_bucket(),
        'Key'    => storage_key($storedName),
    ]);
}

/**
 * Presigned GET address of a file. S3 will return the file with the given type and file name.
 *
 * @param string $disposition "inline" (show in the browser) or "attachment" (download)
 */
function storage_url(string $storedName, string $mime, string $downloadName, string $disposition): string
{
    // Only safe characters in the plain filename; the real UTF-8 name goes in filename*.
    $asciiName = preg_replace('/[^A-Za-z0-9._ -]/', '_', $downloadName);
    $contentDisposition = sprintf(
        '%s; filename="%s"; filename*=UTF-8\'\'%s',
        $disposition,
        $asciiName,
        rawurlencode($downloadName)
    );

    $client = storage_client();
    $command = $client->getCommand('GetObject', [
        'Bucket'                     => storage_bucket(),
        'Key'                        => storage_key($storedName),
        'ResponseContentType'        => $mime,
        'ResponseContentDisposition' => $contentDisposition,
    ]);

    $request = $client->createPresignedRequest($command, '+' . storage_link_ttl() . ' seconds');
    return (string) $request->getUri();
}

/**
 * Send the browser to the file in S3 (HTTP 302). The user's right to see the capsule has already
 * been checked by the controller; S3 knows nothing about application users.
 */
function storage_stream(string $storedName, string $mime, string $downloadName, string $disposition): void
{
    redirect(storage_url($storedName, $mime, $downloadName, $disposition));
}
