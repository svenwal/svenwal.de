#!/bin/sh
hugo
scp -r public/* contabo.walther.network:/var/www/svenwal.de/www/
