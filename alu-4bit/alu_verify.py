def add4(a,b,c):
    s=a+b+c; return s&15, s>>4
def alu(A,B,M,S1,S0):
    a=[(A>>i)&1 for i in range(4)]; b=[(B>>i)&1 for i in range(4)]
    # logic unit: 74153, strobe=M
    sel=S1*2+S0; L=0
    for i in range(4):
        x=a[i]^b[i]; n=[a[i]&b[i], x, 1-(a[i]&b[i]), 1-x][sel]
        L|=(n&(1-M))<<i
    nS1=1-S1; D=nS1&S0; E=S1&S0; Cin=S1^S0
    Y=sum(((a[i] if E else b[i]^D))<<i for i in range(4))
    S,C4=add4(A,Y,Cin)
    N=M&D&(1-C4)
    T=S^(15*N); Z,_=add4(T,0,N)
    R4=M&C4&(1-D)
    R=(R4<<4)|sum((M&((Z>>i)&1))<<i for i in range(4))
    # BCD
    r=[(R>>i)&1 for i in range(5)]
    G1=r[4]&(r[3]|r[2]); X1=(r[4]<<2)|(r[3]<<1)|r[2]
    O1,_=add4(X1,3*G1,0)
    X2=((O1&7)<<1)|r[1]
    G2=((X2>>3)&1)|(((X2>>2)&1)&(((X2>>1)&1)|(X2&1)))
    O2,_=add4(X2,3*G2,0)
    units=((O2&7)<<1)|r[0]; tens=((O1>>3)<<1)|(O2>>3)
    return L,R,N,tens,units
for A in range(16):
 for B in range(16):
  for op in range(8):
    M,S1,S0=op>>2,(op>>1)&1,op&1
    L,R,N,t,u=alu(A,B,M,S1,S0)
    eL=[A&B,A^B,~(A&B)&15,~(A^B)&15,0,0,0,0][op]
    eR=[0,0,0,0,A+B,abs(A-B),A+B+1,2*A][op]
    eN=int(op==5 and A<B)
    assert (L,R,N,t,u)==(eL,eR,eN,eR//10,eR%10),(A,B,op)
print("all 2048 cases OK")
