#!/bin/sh
hugo
scp -r public/* ssh.walther.world:/var/www/svenwal.de/www/
