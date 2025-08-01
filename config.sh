#!/usr/bin/env bash

purple="\033[1;35m"
blue="\033[1;34m"
green="\033[1;32m"
reset="\033[0m"

while true; do
  clear
  echo -e "${purple}🌸 Mitchy's Super Terminal Dashboard 🌸${reset}\n"
  echo -e "${blue}Config Shortcuts:${reset}"
  echo -e "  ${green}nvim${reset}     -> ~/.config/nvim"
  echo -e "  zsh      -> ~/.zshrc"
  echo -e "  tmux     -> ~/.tmux.conf"
  echo -e "  niri     -> ~/.config/niri/config.kdl"
  echo -e "  ghostty  -> ~/.config/ghostty"
  echo -e "  mako     -> ~/.config/mako"
  echo -e "  prism    -> ~/.local/share/PrismLauncher"
  echo
  echo -e "${blue}Navigation Tools:${reset}"
  echo -e "  ${green}fzf${reset}       -> Fuzzy-find any file in ~/.config"
  echo -e "  ${green}zoxide${reset}    -> Jump to recent dirs with zoxide + nvim"
  echo -e "  ${green}projects${reset}  -> Pick from ~/Development"
  echo -e "  ${green}dotfiles${reset}  -> Fuzzy search + edit dotfiles"
  echo
  echo -e "${blue}Extras:${reset}"
  echo -e "  ${green}log${reset}       -> Edit today's markdown journal"
  echo -e "  ${green}sysinfo${reset}   -> Show RAM, disk, CPU temps"
  echo -e "  ${green}custom${reset}    -> Manually cd or edit a file"
  echo -e "  ${green}q${reset}         -> Quit dashboard"
  echo

  read -rp "Enter your choice: " input
  echo

  case "$input" in
    nvim)      cd ~/.config/nvim && nvim . ;;
    zsh)       nvim ~/.zshrc ;;
    tmux)      nvim ~/.tmux.conf ;;
    niri)      nvim ~/.config/niri/config.kdl ;;
    ghostty)   cd ~/.config/ghostty && nvim . ;;
    mako)      cd ~/.config/mako && nvim . ;;
    prism)     cd ~/.local/share/PrismLauncher ;;
    fzf)
      echo -e "${blue}Searching ~/.config...${reset}"
      file=$(find ~/.config -type f 2>/dev/null | fzf)
      [[ -n "$file" ]] && nvim "$file"
      ;;
    zoxide)
      echo -e "${blue}Pick a recent dir with zoxide...${reset}"
      dir=$(zoxide query -ls | fzf | awk '{print $2}')
      [[ -n "$dir" ]] && cd "$dir" && nvim .
      ;;
    projects)
      echo -e "${blue}Projects in ~/Development...${reset}"
      proj=$(find ~/Development -mindepth 1 -maxdepth 1 -type d | fzf)
      [[ -n "$proj" ]] && cd "$proj" && nvim .
      ;;
    dotfiles)
      echo -e "${blue}Fuzzy search dotfiles...${reset}"
      dfile=$(find ~/dotfiles -type f 2>/dev/null | fzf)
      [[ -n "$dfile" ]] && nvim "$dfile"
      ;;
    log)
      today="$HOME/Notes/$(date +%Y-%m-%d).md"
      mkdir -p "$(dirname "$today")"
      nvim "$today"
      ;;
    sysinfo)
      echo -e "${purple}📊 System Info:${reset}"
      echo
      free -h
      echo
      df -h /
      echo
      sensors | grep -E 'Package id|Core' || echo "No sensors found"
      read -rp "Press enter to return..."
      ;;
    custom)
      read -rp "Enter full file or dir path: " path
      if [[ -f "$path" ]]; then
        nvim "$path"
      elif [[ -d "$path" ]]; then
        cd "$path" && nvim .
      else
        echo "❌ Path does not exist."
        read -rp "Press enter to return..."
      fi
      ;;
    q)
      echo -e "${purple}Goodbye, ミッチー! 🌸${reset}"
      break
      ;;
    *)
      echo "❌ Invalid option."
      read -rp "Press enter to return..."
      ;;
  esac
done
