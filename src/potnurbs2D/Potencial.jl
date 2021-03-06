# include("Potencial.jl")
include("dad.jl")
include("decomp.jl")
include("nurbs.jl")
include("CalcHeG.jl")
include("telles.jl")
include("arvore.jl")
include("formatiso.jl")
include("beminterp.jl")
#using Plots
using FastGaussQuadrature
using LinearAlgebra
using SparseArrays
using Statistics
using KrylovMethods
using Test
#gr()
# O número de nós (knots), m, o número de pontos de controle, k, e a ordem da
# curva, n , estão relacionados por:
#                           m = k + n + 1
PONTOS,SEGMENTOS,CCSeg,kmat=dad_0() #Arquivo de entrada de dados
# PONTOS,SEGMENTOS,MALHA,CCSeg,kmat=dad_2() #Arquivo de entrada de dados
# NOS,ELEM=format_dad(PONTOS,SEGMENTOS,MALHA)# formata os dados (cria as
crv=format_dad_iso(PONTOS,SEGMENTOS)# formata os dados
#display(mostra_geo(crv))
dcrv=map(x->nrbderiv(x),crv)
n = length(crv);	# N�mero total de elementos
p=0;#refinamento p

for i=1:n
    degree=crv[i].order-1
    coefs,knots = bspdegelev(degree,crv[i].coefs,crv[i].knots,p)
    crv[i] = nrbmak(coefs,knots)
end

h=5;#refinamento h
for i=1:n
    novosnos=range(0,stop=1,length=h+2)
    degree=crv[i].order-1
    coefs,knots = bspkntins(degree,crv[i].coefs,crv[i].knots,novosnos[2:end-1])
    crv[i] = nrbmak(coefs,knots)
end

Tree1,Tree2,block= cluster(crv,max_elem=8,η = 1.0)#cluster(crv, max_elem=3,η = 1.0)
# E=zeros(length(collocPts),length(collocPts));
# for i=1:length(collocPts)
#     collocCoord[i,:]=nrbeval(crv[numcurva[i]], collocPts[i]);
#     B, id = nrbbasisfun(crv[numcurva[i]],collocPts[i])
#     E[i,id+nnos2[numcurva[i]]]=B
# end
#plot(collocCoord[:,1],collocCoord[:,2])
#legend('Curva resultante','Polígono de controle','Pontos de controle','Pontos fonte')
# H,G,~=CalcHeG(nnos2,crv,kmat)

indfonte,indcoluna,indbezier,tipoCDC,valorCDC,E,collocCoord,collocPts=indices(crv)

HA,bi=Hinterp(Tree1,Tree2,block,crv,kmat,tipoCDC,valorCDC,collocCoord,compressão=false)
A2=montacheia(HA,block,Tree1,Tree2,length(collocPts))
A,B=CalcAeb(indfonte,indcoluna,indbezier, crv, kmat,E,tipoCDC)
b=(B*(E\valorCDC))[:]
xi,f = gmres(vet->matvec(HA,vet,block,Tree1,Tree2,indcoluna),bi,5,tol=1e-5,maxIter=1000,out=0) #GMRES nas matrizes hierarquicas
# xi,f = gmres(A,b,5,tol=1e-5,maxIter=1000,out=0) #GMRES na matriz padrão
# x=A\b # Calcula o vetor x

#
Tc,qc=monta_Teq(tipoCDC,valorCDC,crv, xi) # Separa temperatura e fluxo
#
T=E*Tc
q=E*qc
# norm(A2-A)#erro na aproximação
#plot(T)
L=1
n_pint = 100; # Number of domain points
PONTOS_dom = zeros(n_pint,3);
delta = 0.01; # distance from both ends 
passo = (L-2*delta)/(n_pint-1);
for i = 1:n_pint
    PONTOS_dom[i,:] = [i delta+(i-1)*passo L/2];
end

Tdom = calc_pintpot(PONTOS_dom,indcoluna,indbezier, crv, kmat,Tc,qc)
Tan(x,L=1) = x./L
@test norm(Tdom.^2 .- Tan(PONTOS_dom[:,2]).^2)./size(PONTOS_dom,1) < 10^(-3)
