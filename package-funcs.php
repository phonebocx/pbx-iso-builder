#!/usr/bin/env php
<?php

class Packages
{
	private string $pkgdir;
	private string $dest;
	private string $pkglimit = "";
	private string $webroot = "/tmp/webroot";
	private ?string $devdest = null;
	private ?string $proddest = null;
	private string $url = "https://example.com";

	public function __construct(string $pkgdir, string $dest)
	{
		$this->pkgdir = $pkgdir;
		$this->dest = $dest;
	}

	public function useWebroot(string $webroot): self
	{
		$this->webroot = $webroot;
		return $this;
	}

	public function setBaseUrl(string $url): self
	{
		$this->url = $url;
		return $this;
	}

	public function setDevDest(string $devdest): self
	{
		$this->devdest = $devdest;
		return $this;
	}

	public function getDevDest(): string
	{
		return $this->devdest ?? $this->webroot . "/devpackages.json";
	}

	public function getCurrentDevPackages(): array
	{
		$file = $this->getDevDest();
		if (!file_exists($file)) {
			return [];
		}
		return json_decode(file_get_contents($file), true);
	}

	public function setProdDest(string $proddest): self
	{
		$this->proddest = $proddest;
		return $this;
	}

	public function getProdDest(): string
	{
		return $this->proddest ?? $this->webroot . "/packages.json";
	}

	public function getCurrentProdPackages(): array
	{
		$file = $this->getProdDest();
		if (!file_exists($file)) {
			return [];
		}
		return json_decode(file_get_contents($file), true);
	}

	public function onlyPackage(string $pkg)
	{
		$this->pkglimit = $pkg;
	}

	public function getPkgArr()
	{
		$pkgs = glob($this->pkgdir . "/*/meta");
		$pkgarr = [];
		foreach ($pkgs as $meta) {
			$pkgdir = dirname($meta);
			$pkg = basename($pkgdir);
			if ($this->pkglimit && $this->pkglimit !== $pkg) {
				// Ignore because we've only been asked to do one.
				continue;
			}
			$pkgarr[$pkg] = $this->getGitinfo($pkgdir);
		}
		return $pkgarr;
	}

	public function getGitinfo($pkgdir)
	{
		chdir($pkgdir);
		$tags = ["master" => "master"];
		$cmd = "git tag --list";
		exec($cmd, $tagoutput, $res);
		foreach ($tagoutput as $tag) {
			$tags[$tag] = $tag;
		}
		$retarr = ["releases" => [], "latestdev" => "master", "latestprod" => "", "pkgdir" => $pkgdir];
		$devreleases = [];
		$releases = [];
		foreach ($tags as $name) {
			unset($output, $logoutput);
			// print "Processing package $pkg branch $name\n";
			$cmd = "git checkout --force $name 2>/dev/null";
			exec($cmd, $output, $res);
			if ($res !== 0) {
				var_dump($cmd, $output, $res);
				throw new \Exception("Something didn't work");
			}
			$tagarr = ["commit" => "unreleased", "utime" => 0, "descr" => "No description", "modified" => false];
			// If it's 'master', or the tag name starts with 'dev', it's dev.
			if ($name === "master" || strpos($name, "dev") === 0) {
				$dev = true;
			} else {
				$dev = false;
			}
			$tagarr['dev'] = $dev;
			$cmd = "git log -n1 --date='unix' . 2>/dev/null";
			exec($cmd, $logoutput, $res);
			if ($res !== 0) {
				var_dump($cmd, $logoutput, $res);
				throw new \Exception("Something didn't work");
			}
			foreach ($logoutput as $line) {
				if (!$line) {
					continue;
				}
				if (preg_match('/^commit (.+)$/', $line, $o)) {
					$tagarr['commit'] = $o[1];
					continue;
				}
				if (preg_match('/^Date:\s+(.+)$/', $line, $o)) {
					$tagarr['utime'] = (int) $o[1];
					continue;
				}
				if (preg_match('/^Author: (.+)$/', $line, $o)) {
					$tagarr['author'] = $o[1];
					continue;
				}
				$tagarr['descr'] = trim($line);
			}

			// If this is 'master', subtract 1 second from the utime, so if there is a
			// named tag we prefer that.
			$utime = $tagarr['utime'];
			if ($name == 'master') {
				$utime--;
			}

			if ($dev) {
				$devreleases[$name] = $utime;
			} else {
				$releases[$name] = $utime;
			}
			$tagarr['date'] = gmdate("Y-m-d\TH:i:s\Z", $utime);
			// If there are modified files in this package find the timestamp
			// of the latest modified file, EXCLUDING the pkginfo.json file
			// which is always going to be modified.
			$cmd = "git status -s .";
			exec($cmd, $soutput, $res);
			foreach ($soutput as $line) {
				$filearr = explode(' ', trim($line));
				if (file_exists($filearr[1])) {
					if ($filearr[1] == 'meta/pkginfo.json') {
						continue;
					}
					$s = stat($filearr[1]);
					if ($s['mtime'] > $tagarr['utime']) {
						$tagarr['utime'] = $s['mtime'];
						$tagarr['modified'] = true;
					}
				}
			}
			$retarr['releases'][$name] = $tagarr;
		}

		// Sort out packages by the value (utime), so we can pick the highest.
		// Note that anything called 'master' is one second less than reality.
		arsort($devreleases);
		$retarr['latestdev'] = array_key_first($devreleases);
		// If there's no releases yet, use dev
		if (!$releases) {
			$retarr['latestprod'] = $retarr['latestdev'];
		} else {
			arsort($releases);
			$retarr['latestprod'] = array_key_first($releases);
		}
		return $retarr;
	}

	public function parsePkgArr(?array $pkgarr = null, bool $force = false, bool $showoutput = false)
	{
		if ($pkgarr === null) {
			$pkgarr = $this->getPkgArr();
		}
		$retarr = [];
		foreach ($pkgarr as $pkg => $data) {
			$pkgdir = $data['pkgdir'];
			$retarr[$pkg] = ["pkgdir" => $pkgdir, "tags" => [], "rebuilt" => []];
			foreach ($data['releases'] as $rel => $d) {
				$retarr[$pkg]['tags'][] = $rel;
				$reldest = $this->dest . "/$pkg/" . str_replace('/', '_', $rel);
				$filename = "$reldest/$pkg.squashfs";
				$relmeta = "$filename.meta";
				$shafile = "$filename.sha256";
				$pkgarr[$pkg]['releases'][$rel]['reldest'] = $reldest;
				$pkgarr[$pkg]['releases'][$rel]['squashfs'] = $filename;
				$pkgarr[$pkg]['releases'][$rel]['meta'] = $relmeta;
				$pkgarr[$pkg]['releases'][$rel]['sha256file'] = $shafile;
				$pkgarr[$pkg]['releases'][$rel]['dirinfo'] = $this->genDirinfo($pkg, $rel, $d['commit']);
				if (!is_dir($reldest)) {
					mkdir($reldest, 0777, true);
					chmod($reldest, 0777);
				}
				$rebuild = false;
				if (file_exists($relmeta)) {
					$meta = json_decode(file_get_contents($relmeta), true);
				} else {
					$meta = [];
					$rebuild = true;
				}

				if (file_exists($filename)) {
					if (function_exists('xattr_get')) {
						$currenthash = xattr_get($filename, "sha256");
					} else {
						$currenthash = hash_file("sha256", $filename);
					}
				} else {
					$currenthash = "0";
					$rebuild = true;
				}

				$pkgarr[$pkg]['releases'][$rel]['sha256'] = $currenthash;
				$d['sha256'] = $currenthash;

				$metahash = $meta['sha256'] ?? 'nohash';

				if ($force) {
					if ($showoutput) print "Forcing rebuild of $filename\n";
					$rebuild = true;
				}

				if ($currenthash !== $metahash) {
					if ($showoutput) print "Current '$currenthash' and meta '$metahash' does not match\n";
					$rebuild = true;
				}

				if ($meta != $d) {
					if ($showoutput) {
						print "Meta and d does not match\n";
						print "Meta: " . json_encode($meta) . "\n";
						print "d: " . json_encode($d) . "\n";
					}
					$rebuild = true;
				}
				if (!$rebuild) {
					continue;
				}
				if ($showoutput) print "Changes detected in $pkg at $rel, rebuilding\n";
				$newhash = $this->rebuildPkg($rel, $d, $pkgdir, $filename, $showoutput);
				$d['sha256'] = $newhash;
				$pkgarr[$pkg]['releases'][$rel]['sha256'] = $newhash;
				$retarr[$pkg]['rebuilt'][] = $rel;
				// Note the reldest/filename/meta etc above is not set inside
				// $d, as it wasn't passed by ref, AND, it's not needed, as it
				// will make the $meta == $d comparison much more complicated.
				file_put_contents($relmeta, json_encode($d));
			}
		}
		return ["pkgarr" => $pkgarr, "parsed" => $retarr];
	}

	public function publishPackage(string $pkgrel, array $pkgdata)
	{
		$destdir = $pkgdata['dirinfo']['webdest'];
		$urlbase = $pkgdata['dirinfo']['urlbase'];
		if (!is_dir($destdir)) {
			mkdir($destdir, 0777, true);
			chmod($destdir, 0777);
		}
		$retarr = $pkgdata;
		unset($retarr['reldest'], $retarr['dirinfo']);
		foreach (['squashfs', 'meta', 'sha256file'] as $k) {
			$src = $pkgdata[$k];
			$filename = basename($src);
			$destfile = "$destdir/$filename";
			copy($src, $destfile);
			chmod($destfile, 0777);
			$retarr[$k] = "$urlbase/$filename";
		}
		$retarr['releasename'] = $pkgrel;
		return $retarr;
	}

	public function genDirinfo(string $module, string $branch, string $commit)
	{
		$url = $this->url;
		$webroot = $this->webroot;

		// Double hashing here because I want it hard to get a collision,
		// whilst still keeping the string short. This is, honestly, probably
		// less secure than just doing a single sha256, but better than md5!
		$hash = hash('sha1', hash('sha256', "$module:$branch:$commit"));
		$path = "$webroot/repo/$hash";
		return ["webdest" => $path, "urlbase" => "$url/$hash"];
	}

	public function rebuildPkg($rel, $d, $srcdir, $outfile, bool $showoutput = false)
	{
		if ($showoutput) print "Creating squashfs from $srcdir on branch $rel\n";

		$utime = $d['utime'];
		// Delete the pkginfo file just in case
		$pinfofile = "$srcdir/meta/pkginfo.json";
		if (file_exists($pinfofile)) {
			unlink($pinfofile);
		}
		chdir($srcdir);
		$cmd = "git checkout --force $rel 2>/dev/null";
		exec($cmd, $output, $res);
		if ($res !== 0) {
			var_dump($cmd, $output, $res);
			throw new \Exception("Could not checkout branch $rel");
		}
		if (file_exists('Makefile')) {
			print "Running 'make install' in $srcdir for $rel\n";
			$cmd = "make install 2> /dev/null";
			exec($cmd, $output, $res);
			if ($res !== 0) {
				var_dump($cmd, $output, $res);
				throw new \Exception("Make didn't work");
			}
		}
		if (file_exists($outfile)) {
			unlink($outfile);
		}
		// Create meta/pkginfo.json to put into the squashfs
		$pkginfo = $d;
		unset($pkginfo['sha256']);
		$pkginfo['releasename'] = $rel;
		file_put_contents($pinfofile, json_encode($pkginfo));

		// Make sure this is repeatable - all timestamps in the squashfs are set to the
		// latest commit utime.
		$cmd = "mksquashfs $srcdir $outfile -all-root -mkfs-time $utime -all-time $utime -no-xattrs -e .git";
		exec($cmd, $output, $ret);
		chmod($outfile, 0777);
		$hash = hash_file("sha256", $outfile);
		if (function_exists('xattr_set')) {
			xattr_set($outfile, "sha256", $hash);
		}
		file_put_contents("$outfile.sha256", $hash);
		return $hash;
	}
}
