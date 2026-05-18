.libPaths(c(lib_path, .libPaths())) 
shiny::runApp(app_path, port=3838, host="127.0.0.1", launch.browser=TRUE) 
