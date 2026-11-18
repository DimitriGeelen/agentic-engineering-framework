import re,sys
p,i,ts,root=sys.argv[1:]
t=open(p,encoding='utf-8').read().replace(root,'ROOT').replace(ts,'TS')
# T-5227: an inception's default revisit_at is the filing date + 7; pin the rule, not the day
import datetime
t=t.replace('revisit_at: '+(datetime.date.fromisoformat(ts.strip("'\"")[:10])+datetime.timedelta(days=7)).isoformat(),'revisit_at: TS+7')
sys.stdout.write(re.sub(re.escape(i)+r'(?!\d)','T-ID',t))
