# Generates WIRING.md: pin-by-pin net list for every IC.
Q2 = [(1,2,3),(4,5,6),(9,10,8),(12,13,11)]            # 7408/7400/7486/7432
INV = [(1,2),(3,4),(5,6),(9,8),(11,10),(13,12)]       # 7404
T3 = [(1,2,13,12),(3,4,5,6),(9,10,11,8)]              # 7411
out = ["# قائمة التوصيل طرفاً بطرف (Pin-by-pin)\n",
       "كل اسم في عمود «الشبكة» هو Net Label: كل الأطراف التي تحمل نفس الاسم توصل معاً. "
       "في كل القطع: الطرف 14 أو 16 = VCC (5V)، والطرف 7 أو 8 = GND.\n",
       "المداخل: مفاتيح `A0..A3`، `B0..B3`، `M`، `S1`، `S0`. "
       "المخارج: `L0..L3` و `N` إلى LED عبر 220Ω إلى GND.\n"]
def quad(u, part, gates, pw="14=VCC, 7=GND"):
    out.append(f"\n## {u} — {part} ({pw})\n\n| البوابة | مدخل (طرف) | مدخل (طرف) | مخرج (طرف) |\n|---|---|---|---|")
    for (a,b,y),(na,nb,ny) in zip(Q2, gates):
        out.append(f"| {Q2.index((a,b,y))+1} | {a} = `{na}` | {b} = `{nb}` | {y} = `{ny}` |")
def pins(u, part, rows, pw):
    out.append(f"\n## {u} — {part} ({pw})\n\n| الطرف | الاسم | الشبكة |\n|---|---|---|")
    for p,n,net in rows: out.append(f"| {p} | {n} | `{net}` |")
sp = ("GND","GND","—")
quad("U1","7408",[(f"A{i}",f"B{i}",f"AND{i}") for i in range(4)])
quad("U2","7486",[(f"A{i}",f"B{i}",f"XOR{i}") for i in range(4)])
quad("U3","7400",[(f"A{i}",f"B{i}",f"NAND{i}") for i in range(4)])
out.append("\n## U4 — 7404 (14=VCC, 7=GND)\n\n| العاكس | مدخل (طرف) | مخرج (طرف) |\n|---|---|---|")
for k,((a,y),(na,ny)) in enumerate(zip(INV,[("XOR0","XNOR0"),("XOR1","XNOR1"),("XOR2","XNOR2"),("XOR3","XNOR3"),("S1","nS1"),("C4","nC4")])):
    out.append(f"| {k+1} | {a} = `{na}` | {y} = `{ny}` |")
for u,(i,j) in (("U5",(0,1)),("U6",(2,3))):
    pins(u,"74153",[(1,"~1G","M"),(2,"B (select MSB)","S1"),(14,"A (select LSB)","S0"),
        (6,"1C0",f"AND{i}"),(5,"1C1",f"XOR{i}"),(4,"1C2",f"NAND{i}"),(3,"1C3",f"XNOR{i}"),(7,"1Y",f"L{i}"),
        (15,"~2G","M"),(10,"2C0",f"AND{j}"),(11,"2C1",f"XOR{j}"),(12,"2C2",f"NAND{j}"),(13,"2C3",f"XNOR{j}"),(9,"2Y",f"L{j}")],"16=VCC, 8=GND")
quad("U7","7408",[("nS1","S0","D"),("S1","S0","E"),("R4","OR1","G1"),("P1","OR2","AG2")])
quad("U8","7486",[(f"B{i}","D",f"BX{i}") for i in range(4)])
pins("U9","74157",[(1,"SELECT","E"),(15,"~G","GND"),
    (2,"1A","BX0"),(3,"1B","A0"),(4,"1Y","Y0"),(5,"2A","BX1"),(6,"2B","A1"),(7,"2Y","Y1"),
    (11,"3A","BX2"),(10,"3B","A2"),(9,"3Y","Y2"),(14,"4A","BX3"),(13,"4B","A3"),(12,"4Y","Y3")],"16=VCC, 8=GND")
def adder(u, title, A, B, c0, S, c4):
    pins(u,f"74LS283 — {title}",[(5,"A1",A[0]),(3,"A2",A[1]),(14,"A3",A[2]),(12,"A4",A[3]),
        (6,"B1",B[0]),(2,"B2",B[1]),(15,"B3",B[2]),(11,"B4",B[3]),(7,"C0",c0),
        (4,"Σ1",S[0]),(1,"Σ2",S[1]),(13,"Σ3",S[2]),(10,"Σ4",S[3]),(9,"C4",c4)],"16=VCC, 8=GND")
adder("U10","الجامع الرئيسي",["A0","A1","A2","A3"],["Y0","Y1","Y2","Y3"],"Cin",["S0","S1","S2","S3"] and ["SUM0","SUM1","SUM2","SUM3"],"C4")
quad("U11","7486",[("S1","S0","Cin"),("D","VCC","nD"),sp,sp])
quad("U12","7486",[(f"SUM{i}","N",f"T{i}") for i in range(4)])
out.append("\n## U13 — 7411 (14=VCC, 7=GND)\n\n| البوابة | المداخل (أطراف) | مخرج (طرف) |\n|---|---|---|")
for k,((a,b,c,y),(na,nb,nc,ny)) in enumerate(zip(T3,[("M","D","nC4","N"),("M","C4","nD","R4"),("GND","GND","GND","—")])):
    out.append(f"| {k+1} | {a} = `{na}`، {b} = `{nb}`، {c} = `{nc}` | {y} = `{ny}` |")
adder("U14","القيمة المطلقة",["T0","T1","T2","T3"],["GND"]*4,"N",["Z0","Z1","Z2","Z3"],"غير موصل")
quad("U15","7408",[("M",f"Z{i}",f"R{i}") for i in range(4)])
quad("U16","7432",[("R3","R2","OR1"),("P0","R1","OR2"),("P2","AG2","G2"),sp])
adder("U17","BCD المرحلة 1",["R2","R3","R4","GND"],["G1","G1","GND","GND"],"GND",["P0","P1","P2","P3"],"غير موصل")
adder("U18","BCD المرحلة 2",["R1","P0","P1","P2"],["G2","G2","GND","GND"],"GND",["Q0","Q1","Q2","Q3"],"غير موصل")
def dec(u,t,a,b,c,d):
    pins(u,f"7447 — {t}",[(7,"A",a),(1,"B",b),(2,"C",c),(6,"D",d),(3,"~LT","VCC"),(4,"~BI/RBO","VCC"),(5,"~RBI","VCC"),
        (13,"a","→ 220Ω → a"),(12,"b","→ 220Ω → b"),(11,"c","→ 220Ω → c"),(10,"d","→ 220Ω → d"),(9,"e","→ 220Ω → e"),(15,"f","→ 220Ω → f"),(14,"g","→ 220Ω → g")],"16=VCC, 8=GND")
dec("U19","خانة الآحاد","R0","Q0","Q1","Q2"); dec("U20","خانة العشرات","Q3","P3","GND","GND")
out.append("\nالشاشتان من نوع Common Anode (`SEVEN_SEG_COM_A`): الطرف المشترك CA إلى VCC.\n")
open("WIRING.md","w").write("\n".join(out)+"\n")
