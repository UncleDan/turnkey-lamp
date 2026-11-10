<?php
// fix-short-tags.php by Daniele Lolli (UncleDan) feat. Claude AI - Release 1.0 - 2026-11-10 16-01-58
//
// Rewrite short open tags '<?' as '<?php' (the '<?=' echo tag is left alone, it
// is always available since PHP 5.4). The output of the page is unchanged.
// Must run with short_open_tag=On, e.g.:
//   php -d short_open_tag=On fix-short-tags.php FILE...
// Prints the name of every file it changed.

if (!ini_get('short_open_tag')) {
    fwrite(STDERR, "fatal: run with -d short_open_tag=On\n");
    exit(2);
}

$status = 0;
foreach (array_slice($argv, 1) as $file) {
    $src = @file_get_contents($file);
    if ($src === false) {
        fwrite(STDERR, "warning: cannot read $file\n");
        $status = 1;
        continue;
    }
    if (strpos($src, '<?') === false) {
        continue;
    }
    $out = '';
    $changed = false;
    $toks = token_get_all($src);
    foreach ($toks as $i => $tok) {
        if (is_array($tok) && $tok[0] === T_OPEN_TAG
            && strncasecmp($tok[1], '<?php', 5) !== 0) {
            // '<?' + whatever whitespace the token holds; '<?php' needs a
            // whitespace after it, add one only if none follows
            $rest = substr($tok[1], 2);
            $next = isset($toks[$i + 1]) ? $toks[$i + 1] : null;
            $nextWs = is_array($next) && $next[0] === T_WHITESPACE;
            $tok[1] = '<?php' . ($rest === '' && !$nextWs ? ' ' : $rest);
            $changed = true;
        }
        $out .= is_array($tok) ? $tok[1] : $tok;
    }
    if ($changed) {
        if (file_put_contents($file, $out) === false) {
            fwrite(STDERR, "warning: cannot write $file\n");
            $status = 1;
            continue;
        }
        echo $file, "\n";
    }
}
exit($status);
