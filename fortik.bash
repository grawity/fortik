#!/usr/bin/env bash

die() { echo "$*" >&2; exit 1; }

parse() {
	declare text=$1
	declare -i i=0
	declare -a tokens=()
	read -r -a tokens -d '' <<< "$text"
	for (( i=0; i<${#tokens[@]}; i++ )); do
		if [[ ${tokens[i]} == : ]]; then
			name=${tokens[++i]}
			while (( i<${#tokens[@]} )); do
				case ${tokens[++i]} in
				':') die "cannot define word while defining word";;
				';') break;;
				*) wordsrc[$name]+="${tokens[i]} ";;
				esac
			done
		elif [[ ${tokens[i]} == \; ]]; then
			die "unexpected end of word definition"
		elif [[ ${tokens[i]} =~ ^[0-9]+$ ]]; then
			Code+=('NUM' "${tokens[i]}")
		elif [[ ${tokens[i]} == repeat ]]; then
			Code+=('LPUSH' 'LOOP' "${tokens[++i]}")
		elif [[ ${tokens[i]} == ifelse ]]; then
			Code+=('BRANCH' "${tokens[++i]}" "${tokens[++i]}")
		else
			Code+=('CALL' "${tokens[i]}")
		fi
	done
	Code+=('RET')
}

cpu() {
	readonly -a code=("${Code[@]}")
	declare sa= sb=
	declare -i ip=0 sp=0 csp=0 lsp=0 end=${#code[@]} ra=0 rb=0 rc=0
	declare -ai stack=() cstack=() lstack=()
	while (( ip < end )); do
		case ${code[ip]} in
		'NUM')
			stack[++sp]=code[++ip] ;;
		'CALL')
			sa=${code[++ip]}
			case $sa in
			'+') rb=stack[sp--] ra=stack[sp--]; stack[++sp]='ra+rb';;
			'-') rb=stack[sp--] ra=stack[sp--]; stack[++sp]='ra-rb';;
			'*') rb=stack[sp--] ra=stack[sp--]; stack[++sp]='ra*rb';;
			'/') rb=stack[sp--] ra=stack[sp--]; stack[++sp]='ra/rb';;
			'<') rb=stack[sp--] ra=stack[sp--]; stack[++sp]='ra<rb';;
			'.') ra=stack[sp--]; echo "$ra";;
			'dup') ra=stack[sp]; stack[++sp]=ra;;
			'drop') ((sp--));;
			'emit') ra=stack[sp--]; printf -v sb %o $ra; LC_ALL=C printf "\\$sb";;
			*)
				[[ ${Words[$sa]} ]] || die "unknown word '$sa'"
				cstack[++csp]=ip
				ip=${Words[$sa]}
				continue ;;
			esac ;;
		'RET')
			((csp)) || return 0
			ip=cstack[csp--] ;;
		'LPUSH')
			lstack[++lsp]=stack[sp--] ;;
		'LOOP')
			sa=${code[++ip]}
			if ((lstack[lsp]--)); then
				[[ ${Words[$sa]} ]] || die "unknown word '$sa'"
				cstack[++csp]=ip-2
				ip=${Words[$sa]}
				continue
			else
				((lsp--))
			fi ;;
		'BRANCH')
			sa=${code[++ip]}; [[ ${Words[$sa]} ]] || die "unknown word '$sa'"
			sb=${code[++ip]}; [[ ${Words[$sb]} ]] || die "unknown word '$sb'"
			rc=stack[sp--]
			ra=${Words[$sa]}
			rb=${Words[$sb]}
			cstack[++csp]=ip
			ip='rc?ra:rb'
			continue ;;
		*)
			die "bad op '${code[ip]}' @ $ip" ;;
		esac
		((++ip))
	done
}

run() {
	declare -a Code=()
	declare -Ai Words=()
	declare -A wordsrc=()
	parse "$1"
	declare w
	for w in "${!wordsrc[@]}"; do
		Words[$w]=${#Code[@]}
		parse "${wordsrc[$w]}"
	done
	cpu
}

src='
: cr 10 emit ;
: star 42 emit ;
: star-line dup repeat star cr ;
: star-rect repeat star-line drop ;
4 8 star-rect
: fact1 drop 1 ;
: fact2 dup 1 - fact * ;
: fact dup 1 < ifelse fact1 fact2 ;
5 fact .
'

run "${1:-"$src"}"
