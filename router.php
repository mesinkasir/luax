<?php
$uri = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
$path = __DIR__ . "/dist" . $uri;
if (is_file($path)) {
    return false;
}
if (is_dir($path)) {
    $index = rtrim($path, "/") . "/index.html";
    if (file_exists($index)) {
        $ext = pathinfo($index, PATHINFO_EXTENSION);
        if ($ext == "html") header("Content-Type: text/html");
        readfile($index);
        return true;
    }
}
$pretty = __DIR__ . "/dist" . rtrim($uri, "/") . "/index.html";
if (file_exists($pretty)) {
    header("Content-Type: text/html");
    readfile($pretty);
    return true;
}
http_response_code(404);
echo "404 - Not Found: " . $uri;
return true;
