"""Mapa tela<->mundo da camera de fidelidade V7 (ortografica, yaw/pitch ajustados ao campo arado)."""
import numpy as np, json, sys
PSI, THETA, SIZE = 50.0, 28.0, 20.0
def basis():
    p,t=np.radians(PSI),np.radians(THETA)
    b=np.array([np.cos(t)*np.sin(p),np.sin(t),np.cos(t)*np.cos(p)]); r=np.array([np.cos(p),0,-np.sin(p)]); u=np.cross(b,r)
    return r,u,b
K=SIZE/900.0
def to_screen(P,T):
    r,u,b=basis(); d=np.array(P)-T; return 800+d@r/K, 450-d@u/K
def to_world(px,py,T,h=0.0):
    r,u,b=basis(); O=T+r*(px-800)*K+u*(450-py)*K
    t=(O[1]-h)/b[1]; return O-b*t
# ancora: pes do jogador (0,0,2) aparecem em (762,500)
T0=np.zeros(3); sx,sy=to_screen([0,0,2],T0)
r,u,b=basis(); T=T0+r*(sx-762)*K+u*(450-(500-(sy-450)))*0
# resolver T numericamente
T=np.zeros(3)
for _ in range(50):
    sx,sy=to_screen([0,0,2],T); T=T+r*(sx-762)*K-u*(sy-500)*K
    T[1]=0; 
if __name__=="__main__":
    print("T",np.round(T,3), to_screen([0,0,2],T))
    pts=json.load(open(sys.argv[1],encoding="utf-8"))
    for k,v in pts.items():
        w=to_world(v[0],v[1],T,v[2] if len(v)>2 else 0.0); print(f"{k:28s} {v} -> ({w[0]:6.2f}, {w[1]:5.2f}, {w[2]:6.2f})")