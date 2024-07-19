#!/usr/bin/env php
<?php

$opts = getopt("d:p:f", ["dest:", "jfilename:", "force", "pkgdir:"]);
$force = false;

if (isset($opts['f']) || isset($opts['force'])) {
	$force = true;
}

$jfilename = $opts['jfilename'] ?? "packages.json";

$dest = $opts['d'] ?? $opts['dest'] ?? false;
if (!$dest) {
	$dest = __DIR__ . "/src/packages";
}

$srcdir = $opts['p'] ?? $opts['pkgdir'] ?? false;
if (!$srcdir) {
	$srcdir = __DIR__ . "/packages";
}

print "Saving to $dest with $jfilename using packages in $srcdir";
if (!is_dir($dest)) {
	mkdir($dest, 0777, true);
	chmod($dest, 0777);
}

$pkglimit = $opts['p'] ?? false;
if ($pkglimit) {
	print " (Only packaging $pkglimit)";
}
print "\n";

$pkgs = glob($srcdir . "/*/meta");
$pkgarr = [];
foreach ($pkgs as $meta) {
	$pkgdir = dirname($meta);
	$pkg = basename($pkgdir);
	if ($pkglimit && $pkglimit !== $pkg) {
		print "Ignorning $pkg because of packagelimit $pkglimit\n";
		continue;
	}
	$git = get_gitinfo($pkgdir);
	@unlink("$pkgdir/meta/pkginfo.json");
	file_put_contents("$pkgdir/meta/pkginfo.json", json_encode($git));
	$pkgarr[$pkg] = $git;
}

if (!file_exists("$dest/$jfilename")) {
	$origp = [];
} else {
	$origp = json_decode(file_get_contents("$dest/$jfilename"), true);
}

foreach ($pkgarr as $pkg => $data) {
	$filename = "$dest/$pkg.squashfs";
	$json = json_encode($data);
	if (file_exists($filename . ".meta")) {
		$meta = file_get_contents($filename . ".meta");
		if ($meta == $json) {
			$hash = $origp[$pkg]['sha256'] ?? false;
			if (!$hash) {
				print "No hash for $pkg, rebuilding\n";
			} else {
				$pkgarr[$pkg]['sha256'] = $hash;
				if (!$force) {
					print "$pkg unchanged, not rebuilding\n";
					continue;
				}
			}
		}
	}
	@unlink($filename . ".meta");
	file_put_contents($filename . ".meta", $json);
	$pkgarr[$pkg]['sha256'] = rebuild_pkg($srcdir . "/$pkg", $filename);
}

@unlink("$dest/$jfilename");
print "Saving package build output to $dest/$jfilename\n";
file_put_contents("$dest/$jfilename", json_encode($pkgarr));
// var_dump("$dest/packages.json", json_encode($pkgarr));

function rebuild_pkg($srcdir, $outfile)
{
	if (file_exists($outfile)) {
		unlink($outfile);
	}
	$cmd = "mksquashfs $srcdir $outfile -all-root -no-xattrs -e .git";
	exec($cmd, $output, $ret);
	// print "$cmd exited with $ret\n";
	chmod($outfile, 0777);
	$hash = hash_file("sha256", $outfile);
	file_put_contents("$outfile.sha256", $hash);
	return $hash;
}


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
	foreach ($soutput as $line) {
		$retarr['modified'] = true;
		$filearr = explode(' ', trim($line));
		if (file_exists($filearr[1])) {
			$s = stat($filearr[1]);
			if ($s['mtime'] > $retarr['utime']) {
				$retarr['utime'] = $s['mtime'];
			}
		}
	}
	return $retarr;
}
