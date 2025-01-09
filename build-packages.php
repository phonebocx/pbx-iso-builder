#!/usr/bin/env php
<?php

include __DIR__ . "/package-funcs.php";

$url = "http://example.com/repo";
$webroot = "/var/www/html/webroot";

$opts = getopt("d:p:f", ["dest:", "jfilename:", "force", "pkgdir:"]);
$force = false;

if (isset($opts['f']) || isset($opts['force'])) {
	$force = true;
}

$jfilename = $opts['jfilename'] ?? "packages.json";

$dest = $opts['d'] ?? $opts['dest'] ?? false;
if (!$dest) {
	$dest = __DIR__ . "/baserepo";
}

$srcdir = $opts['p'] ?? $opts['pkgdir'] ?? false;
if (!$srcdir) {
	$srcdir = __DIR__ . "/git";
}

print "Saving to $dest with $jfilename using packages in $srcdir";
if (!is_dir($dest)) {
	mkdir($dest, 0777, true);
	chmod($dest, 0777);
}

$p = new Packages($srcdir, $dest);

$pkglimit = $opts['p'] ?? false;
if ($pkglimit) {
	print " (Only packaging $pkglimit)";
	$p->onlyPackage($pkglimit);
}
print "\nPublishing to $url using webroot $webroot\n";
$p->useWebroot($webroot);

$v = $p->parsePkgArr(null, $force, true);

$devpackages = $p->getCurrentDevPackages();
$prodpackages = $p->getCurrentProdPackages();

$pkgarr = $v['pkgarr'];
// Now loop over them again to generate the main package json
foreach ($pkgarr as $pkg => $data) {
	$latestdev = $data['latestdev'];
	$latestprod = $data['latestprod'];
	foreach ($data['releases'] as $rel => $d) {
		if ($rel == $latestdev) {
			$devpackages[$pkg] = $p->publishPackage($rel, $d);
		}
		if ($rel == $latestprod) {
			$prodpackages[$pkg] = $p->publishPackage($rel, $d);
		}
	}
}

$djson = json_encode($devpackages);
$pjson = json_encode($prodpackages);
$devdest = $p->getDevDest();
$proddest = $p->getProdDest();
file_put_contents($devdest, $djson);
file_put_contents($proddest, $pjson);
print "Updated $proddest and $devdest\n";
