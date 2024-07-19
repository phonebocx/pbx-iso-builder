#!/usr/bin/env php
<?php

$basedir = $argv[1] ?? __DIR__ . "/../";
if (!is_dir("$basedir/.git")) {
    $ret = ["commit" => "unknown", "utime" => "0", "descr" => "$basedir not a git repo", "modified" => true];
} else {
    $ret = get_gitinfo($basedir);
}

$vars = ["BUILDUTIME", "BUILD", "THEME", "KFIRMWARE", "BRANCH", "KERNELVER", "KERNELREL"];
$e = getenv();
$ret['buildenv'] = [];
foreach ($vars as $v) {
    $ret['buildenv'][$v] = $e[$v] ?? "__unset__";
}
$pdd = $e['PKGDESTDIR'];
$pj = json_decode(file_get_contents("$pdd/packages.json"), true);
$ret['packages'] = $pj;
print json_encode($ret) . "\n";

function get_gitinfo($pkgdir)
{
    chdir($pkgdir);
    $retarr = ["commit" => "unreleased", "utime" => "0", "descr" => "No description", "modified" => true];
    $cmd = "git log -n1 . 2>/dev/null";
    exec($cmd, $output, $res);
    if ($res != 0) {
        return $retarr;
    }
    foreach ($output as $line) {
        if (!$line) {
            continue;
        }
        if (preg_match('/^commit (.+)$/', $line, $o)) {
            $retarr['commit'] = $o[1];
            continue;
        }
        if (preg_match('/^Date:\s+(.+)$/', $line, $o)) {
            $retarr['date'] = $o[1];
            continue;
        }
        if (preg_match('/^Author: (.+)$/', $line, $o)) {
            $retarr['author'] = $o[1];
            continue;
        }
        $retarr['descr'] = trim($line);
        break;
    }
    $retarr['utime'] = @strtotime($retarr['date']);
    $cmd = "git status -s .";
    exec($cmd, $soutput, $res);
    if (!$soutput) {
        $retarr['modified'] = false;
        return $retarr;
    }
    $retarr['changes'] = [];
    foreach ($soutput as $line) {
        $retarr['modified'] = true;
        $filearr = explode(' ', trim($line));
        $filepath = array_pop($filearr);
        $changetype = array_shift($filearr);
        $retarr['changes'][$filepath] = $changetype;
        // Update the mtime?
        if (file_exists($filepath)) {
            $s = stat($filepath);
            if ($s['mtime'] > $retarr['utime']) {
                $retarr['utime'] = $s['mtime'];
            }
        }
    }
    return $retarr;
}
