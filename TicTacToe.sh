#!/usr/bin/env zsh

fifo_name="/tmp/user_input_$$"
mkfifo $fifo_name

function clear_terminal() {
    echo -en "\e[H\e[2J"
}

function game_exit() {
    reset
    clear_terminal
    rm -f $fifo_name
    exit
}

function get_mouse() {
    echo -en "\033[?1000h"

    while read -r -k1 char; do
        if [[ "$char" == $'\033' ]]; then
            if read -r -k2 seq && [[ "$seq" == '[M' ]]; then
                if read -r -k3 data; then
                    local event_type="$data[1]"
                    local x_char="$data[2]"
                    local y_char="$data[3]"
                    
                    local -i event_code=$(( #event_type ))
                    local -i x=$(( #x_char - 32 ))
                    local -i y=$(( #y_char - 32 ))
                    
                    if [[ "$event_type" == ' ' ]]; then
                        echo -en "$x;$y" > $fifo_name
                    fi
                fi
            fi
        fi
    done
}

original_stty=$(stty -g)
stty -echo -icanon
trap 'game_exit' INT TERM EXIT
get_mouse &
mouse_pid=$!
echo -ne "\e[?25l"
clear_terminal

function draw_board() {
    clear_terminal
    local board_array=("$@")
    for i in {1..9}; do
        case ${board_array[$i]} in
            0) echo -en "・" ;;
            1) echo -en "Ｘ" ;;
            2) echo -en "Ｏ" ;;
            *) echo -en "？" ;;
        esac
        if (( $i % 3 == 0 )); then
            echo -en "\n"
        fi
    done
}

function get_cell_number() {
    local x=$1
    local y=$2
    
    if (( x < 1 || x > 6 || y < 1 || y > 3 )); then
        return 1
    fi
    
    local col=$(( (x + 1) / 2 ))
    local row=$y
    local cell_number=$(( (row - 1) * 3 + col ))
    echo $cell_number
}

function check_game_state() {
    local board_array=("$@")
    local winner=0
    
    local winning_combinations=(
        "1 2 3" "4 5 6" "7 8 9"
        "1 4 7" "2 5 8" "3 6 9"
        "1 5 9" "3 5 7"
    )
    
    for combo in "${winning_combinations[@]}"; do
        local cells=(${=combo})
        local a=${board_array[${cells[1]}]}
        local b=${board_array[${cells[2]}]}
        local c=${board_array[${cells[3]}]}
        
        if [[ $a -ne 0 && $a -eq $b && $a -eq $c ]]; then
            winner=$a
            echo $winner
            return 0
        fi
    done
    
    for i in {1..9}; do
        if [[ ${board_array[$i]} -eq 0 ]]; then
            return 1
        fi
    done
    
    echo 3
    return 0
}

board=(0 0 0 0 0 0 0 0 0)
step=0
game_over=0
draw_board "${board[@]}"

while true; do
    local input=$(cat $fifo_name)
    local inputy=${input#*;}
    local inputx=${input%;*}
    if get_cell_number $inputx $inputy > /dev/null; then
        local cell_number=$(get_cell_number $inputx $inputy)
        if [ "${board[$cell_number]}" = 0 ]; then
            board[$cell_number]=$(( step % 2 + 1 ))
            draw_board "${board[@]}"
            (( step++ ))

            local game_state=$(check_game_state "${board[@]}")
            case $game_state in
                1) echo -e "\nX 胜利！"; game_over=1 ;;
                2) echo -e "\nO 胜利！"; game_over=1 ;;
                3) echo -e "\n平局…"; game_over=1 ;;
            esac

            if [ $game_over = 1 ]; then
                break
            fi
        fi
    fi
done

kill $mouse_pid 2> /dev/null
wait $mouse_pid 2> /dev/null

echo "按下 ^C 退出"

while true; do
    sleep 1
done