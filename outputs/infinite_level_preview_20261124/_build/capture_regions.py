from build_preview import build, chrome, BUILD, OUT

target=build()
source=target.read_text(encoding="utf-8")
for index,boss in [(1,False),(2,False),(3,False),(4,False),(4,True)]:
    setup=f"window.previewReady.then(()=>{{previewApi.setLevel({index});previewApi.setTime({300 if boss else 190});{'previewApi.enterBoss();' if boss else ''}previewApi.render();}});"
    fixture=BUILD/"region_capture.html"
    fixture.write_text(source.replace("</body>","<script>"+setup+"</script></body>"),encoding="utf-8")
    name=f"region_{index+1}{'_boss' if boss else ''}"
    chrome(["--window-size=1600,1000","--virtual-time-budget=1200",
            "--screenshot="+str(BUILD/(name+".png")),fixture.as_uri()],name+".log")
    print("Captured",name,flush=True)
