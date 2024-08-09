package main

import (
	"encoding/xml"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
)

var (
	bindHost = flag.String("host", "127.0.0.1", "Bind on address")
	bindPort = flag.Int("port", 5070, "Bind on port")
)

func init() {
	flag.Parse()
	log.SetOutput(os.Stdout)
	runtime.GOMAXPROCS(runtime.NumCPU())
}

func main() {
	http.Handle("/fsapi", http.HandlerFunc(router))

	bind := fmt.Sprintf("%s:%d", *bindHost, *bindPort)
	log.Print("Listen on: ", bind)
	log.Fatal(http.ListenAndServe(bind, nil))
}

func router(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		r.ParseForm()

		w.Header().Set("Content-Type", "application/xml")
		w.Write([]byte(xml.Header))

		if len(r.FormValue("Unique-ID")) > 0 {
			log.SetPrefix("[" + r.FormValue("Unique-ID") + "] ")
		} else {
			log.SetPrefix("")
		}

		log.Println(r.Form)

		switch r.FormValue("section") {
		case "dialplan":
			Dialplan(w, r)
		default:
			NotFound(w, r)
		}

	} else {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
}
