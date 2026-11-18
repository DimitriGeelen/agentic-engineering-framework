import re,sys
p,i,ts,root=sys.argv[1:]
t=open(p,encoding='utf-8').read().replace(root,'ROOT').replace(ts,'TS')
sys.stdout.write(re.sub(re.escape(i)+r'(?!\d)','T-ID',t))
