SET R_LIBS_USER=.\R\Library
.\R\bin\Rscript.exe -e "shiny::runApp('app', port=3838, host='127.0.0.1', launch.browser=TRUE)" 
::.\R\bin\R.exe