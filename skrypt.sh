#!/bin/bash
# Author           : Jozef Sztabinski ( s197890@student.pg.edu.pl )
# Created On       : data
# Last Modified By : Jozef Sztabinski ( s197890@student.pg.edu.pl )
# Last Modified On : 26.05.2024 
# Version          : 1.0
#
# Description      : Simple bash script for scrolling through the audio library (supports .mp3, .wav, .ogg), editing the ID3 tag metadata (title, artist, album, genre).
# Opis               Prosty skrypt do przegladania biblioteki audio, edycji tagow ID3 (tytul, artysta, album, gatunek) oraz konwersji mp3-to-wav i vice versa.
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)



setTitle(){
  id3v2 "$1" --song $2
}
setArtist(){
  id3v2 "$1" --artist "$2"
}
setAlbum(){
  id3v2 "$1" --album "$2"
}
setGenre(){
  id3v2 "$1" --genre "$2"
}

fillId3Tag(){
  #TPE1 = artist
  if [[ $tagInput != *"TPE1"* ]]; then
    id3v2 "$fileName" --artist UNKNOWN
  fi
  #TALB = album
  if [[ $tagInput != *"TALB"* ]]; then
    id3v2 "$fileName" --album UNKNOWN
  fi
  #TIT2 = title
  if [[ $tagInput != *"TIT2"* ]]; then
    id3v2 "$fileName" --song UNKNOWN
  fi
  #TCON = genre
  if [[ $tagInput != *"TCON"* ]]; then
    id3v2 "$fileName" --genre UNKNOWN
  fi
}


parsingTags(){
  #check if tag exists
  for i in "${audioFileNames[@]}"
  do
    tagInput="$(id3v2 -R "$i")"
    fillId3Tag $tagInput $i;
  done
}

getTitle(){
  title="$(echo $tagInput | grep -o "TIT2.*" | cut -d ":" -f 2 | rev | cut -d " " -f 2- | rev | cut -c 2-)"

}

getArtist(){
  artist="$(echo $tagInput | grep -o "TPE1.*" | cut -d ":" -f 2 | rev | cut -d " " -f 2- | rev | cut -c 2-)"
}

getAlbum(){
  album="$(echo $tagInput | grep -o "TALB.*" | cut -d ":" -f 2 | rev | cut -d " " -f 2- | rev | cut -c 2-)"
}

getGenre(){
  genre="$(echo $tagInput | grep -o "TCON.*" | cut -d ":" -f 2 | rev | cut -d "(" -f 2- | cut -d " " -f 2-| rev | cut -c 2-)"
}

getNeededData(){
  title=""
  getTitle $title $tagInput
  artist=""
  getArtist $artist $tagInput
  album=""
  getAlbum $album $tagInput
  genre=""
  getGenre $genre $tagInput
  echo "${title// /\\}" "${artist// /\\}" "${album// /\\}" "${genre// /\\}"
}

makeLine(){
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

showingFiles(){
  clear
  makeLine
  printf "PAGE: %d/%d\n" "$pageNum" "$maxPages"
  for j in {1..10}
  do
    recordNum=$((10*pageNum+j))
    if [[ ${#audioFileNames[@]} -le recordNum ]]; then
      return
    fi

    
    i="${audioFileNames[recordNum]}"

    tagInput="$(id3v2 -R "$i" | grep -E 'TIT2|TALB|TCON|TPE1')"
    tagInput="${tagInput} :"
    printf "%d %s " "$recordNum" "${i// /\\}" 
    getNeededData $tagInput
    echo
  done | column -t \
    --table-wrap FileName,Title,Artist,Album,Genre \
    --table-columns Nr,FileName,Title,Artist,Album,Genre \
    --keep-empty-lines

  makeLine
  makeLine
  echo "q-quit, c-choose file, ARROW: DOWN-Next Page, UP-Previous Page"
  makeLine
}


convertMp3ToWav(){
  outputFile="$(echo $calledFile | rev | cut -d "." -f 2- | rev).wav"
  
  ffmpeg -i "$calledFile" "$outputFile"
  tagInput="$(id3v2 -R "$calledFile" | grep -E 'TIT2|TALB|TCON|TPE1')"
  tagInput="${tagInput} :"
  title=""
  artist=""
  album=""
  genre=""
  getTitle $tagInput $title
  getArtist $tagInput $artist
  getAlbum $tagInput $album
  getGenre $tagInput $genre


  setTitle $outputFile $title
  setArtist $outputFile $artist
  setAlbum $outputFile $album
  setGenre $outputFile $genre

  echo $outputFile
}

convertWavToMp3(){
  outputFile="$(echo $calledFile | rev | cut -d "." -f 2- | rev).mp3"
  
  ffmpeg -hide_banner -i "$calledFile" "$outputFile"
  tagInput="$(id3v2 -R "$calledFile" | grep -E 'TIT2|TALB|TCON|TPE1')"
  tagInput="${tagInput} :"
  title=""
  artist=""
  album=""
  genre=""
  getTitle $tagInput $title
  getArtist $tagInput $artist
  getAlbum $tagInput $album
  getGenre $tagInput $genre


  setTitle $outputFile $title
  setArtist $outputFile $artist
  setAlbum $outputFile $album
  setGenre $outputFile $genre

  echo $outputFile
}




#start
pageNum=0
readarray -t unsortedAudioFileNames < <(find . -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" | sed -e 's,^\./,,' )
IFS=$'\n' audioFileNames=($(sort -n <<<"${unsortedAudioFileNames[*]}"))
arrSize=${#audioFileNames[@]}
maxPages=$((arrSize/10))
showingFiles $audioFileNames $pageNum $maxPages


while (true); do
  escape_char=$(printf "\u1b")
  read -rsn1 mode
  if [[ $mode == $escape_char ]]; then
    read -rsn2 mode
  fi
  case $mode in
    'q') 
      echo QUITTING
      sleep 1
      clear 
      exit;;
    '[A')
        if [[ $pageNum -gt 0 ]]; then
          pageNum=$((pageNum-1)) 
          showingFiles $audioFileNames $pageNum $maxPages
        fi
        ;;
    '[B') 
        if [[ $pageNum -lt $maxPages ]]; then
          pageNum=$((pageNum+1)) 
          showingFiles $audioFileNames $pageNum $maxPages
        fi
        ;;
    'c')
        read -p "Choose file to edit (Nr):" chosenNum
        if [ "$chosenNum" -lt "0" ] || [ $chosenNum -ge $arrSize ]; then
          echo "INVALID FILE NUM!"
        else
          calledFile=${audioFileNames[chosenNum]}
          tagInput="$(id3v2 -R "$calledFile" | grep -E 'TIT2|TALB|TCON|TPE1')"
          tagInput="${tagInput} :"
          makeLine
          echo "1 - change title, 2 - change artist, 3 - change album, 4 - change genre, 5 - convert mp3-to-wav, 6 - convert wav-to-mp3, 7 - play it!"
          makeLine
          read -p "Chose opt: " chosenOpt
          defValue=""
          case $chosenOpt in
            1)
              title=""
              getTitle $tagInput $title
              defValue=$title
             ;;
            2)
              artist=""
              getArtist $tagInput $artist 
              defValue=$artist
              ;;
            3)
              album=""
              getAlbum $tagInput $album
              defValue=$album
              ;;
            4)
              genre=""
              getGenre $tagInput $genre
              defValue=$genre
              ;;
            5)
              if [[ $calledFile == *.mp3 ]]; then
                convertMp3ToWav $calledFile
                readarray -t unsortedAudioFileNames < <(find . -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" | sed -e 's,^\./,,' )
                IFS=$'\n' audioFileNames=($(sort -n <<<"${unsortedAudioFileNames[*]}"))
                arrSize=${#audioFileNames[@]}
                maxPages=$((arrSize/10))
              else
                echo "Not a mp3 file!"
                sleep 2
              fi
              ;;
            6)
              if [[ $calledFile == *.wav ]]; then
                convertWavToMp3 $calledFile
                readarray -t unsortedAudioFileNames < <(find . -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" | sed -e 's,^\./,,' )
                IFS=$'\n' audioFileNames=($(sort -n <<<"${unsortedAudioFileNames[*]}"))
                arrSize=${#audioFileNames[@]}
                maxPages=$((arrSize/10))
              else
                echo "Not a wav file!"
                sleep 2
              fi
              ;;

            7)
              makeLine
              echo "Playback options [ffplay]"
              echo "p - pause, q - quit, for more info check ffplay docs"
              makeLine
              ffplay -v 0 "$calledFile"
              ;;
          esac
          if [ $chosenOpt -ge 1 ] && [ $chosenOpt -le 4 ]; then
            read -r -e -p "New value: " -i $defValue newValue

            case $chosenOpt in
            1)
              setTitle $calledFile $newValue
             ;;
            2)
              setArtist $calledFile $newValue
              ;;
            3)
              setAlbum $calledFile $newValue
              ;;
            4)
              setGenre $calledFile $newValue
              ;;
              esac
          fi
          showingFiles $audioFileNames $pageNum $maxPages

        fi
        ;;
  esac
done
