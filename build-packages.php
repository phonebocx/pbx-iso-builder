#!/usr/bin/env php
<?php

include __DIR__ . "/package-funcs.php";

$url = "http://example.com/repo";
$webroot = "/var/www/html/webroot";

$opts = getopt("d:f", ["devpackages", "dest:", "staging:", "jfilename:", "force", "pkgsrcdir:"]);
$force = false;

if (isset($opts['f']) || isset($opts['force'])) {
	$force = true;
}

$stagingdir = $opts['staging'] ?? false;
if (!$stagingdir) {
	throw new \Exception("Need to provide a staging directory");
}

$dest = $opts['d'] ?? $opts['dest'] ?? false;
if (!$dest) {
	throw new \Exception("Need to provide a final destination directory");
}
if (array_key_exists('devpackages', $opts)) {
	$installdevpkgs = true;
} else {
	$installdevpkgs = false;
}

$srcdir = $opts['p'] ?? $opts['pkgsrcdir'] ?? false;
if (!$srcdir) {
	throw new \Exception("No pkgsrcdir provided");
}

if (!is_dir($srcdir)) {
	throw new \Exception("$srcdir does not exist");
}

if (!is_dir($dest)) {
	mkdir($dest, 0777, true);
	chmod($dest, 0777);
}

print "Staging to $stagingdir using ";
if ($installdevpkgs) {
	print "DEVELOPMENT PACKAGES from $srcdir ";
} else {
	print "released packages from $srcdir ";
}

$jfilename = $opts['jfilename'] ?? "$stagingdir/fullpackages.json";

$p = new Packages($srcdir, $stagingdir);

$p->useWebroot($webroot);

$v = $p->parsePkgArr(null, $force, true);

$devpackages = $p->getCurrentDevPackages();
$prodpackages = $p->getCurrentProdPackages();

$pkgarr = $v['pkgarr'];
file_put_contents($jfilename, json_encode($pkgarr));

// Now loop over them again to generate the main package json
foreach ($pkgarr as $pkg => $data) {
	$latestdev = $data['latestdev'];
	$latestprod = $data['latestprod'];
	foreach ($data['releases'] as $rel => $d) {
		if ($rel == $latestdev) {
			$devpackages[$pkg] = $d;
			$devpackages[$pkg]['rel'] = $rel;
		}
		if ($rel == $latestprod) {
			$prodpackages[$pkg] = $d;
			$prodpackages[$pkg]['rel'] = $rel;
		}
	}
}

if ($installdevpkgs) {
	$src = $devpackages;
} else {
	$src = $prodpackages;
}
$isopackages = [];
foreach ($src as $p => $d) {
	foreach (['squashfs', 'meta', 'sha256file'] as $s) {
		$srcfile = $d[$s];
		if (!file_exists($srcfile)) {
			throw new \Exception("Hang on $srcfile does not exist in package $p");
		}
		$destfile = $dest . "/" . basename($srcfile);
		copy($srcfile, $destfile);
	}
	$tmparr = [];
	foreach (['commit', 'utime', 'descr', 'modified', 'author', 'date', 'rel'] as $x) {
		$tmparr[$x] = $d[$x];
	}
	$isopackages[$p] = $tmparr;
}
file_put_contents("$dest/packages.json", json_encode($isopackages));
print "Saved to $dest/packages.json\n";
