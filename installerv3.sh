#!/bin/bash
# curl -sL https://git.io/fxWcp | bash

logger(){
	echo -e "${CYAN}Output & Error logging has now been enabled.:${WHITE} ~/.stdout.log stderr.log${NC}\n"
	exec 1> >(tee "stdout.log")
	exec 2> >(tee "stderr.log")
	sleep 5
}

logger
