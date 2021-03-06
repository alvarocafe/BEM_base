function cal_Aeb(b1,b2,arg)
  NOS,NOS_GEO,ELEM,qsi,w,CDC,k=arg
  nelem::Int64=size(ELEM)[1]; # Número de elementos (n�mero de linhas da matriz ELEM)

  G=zeros(length(b1),length(b2));
  H=zeros(length(b1),length(b2));
  q=zeros(length(b1),1);
  ci=0
  for i in b1 # Laco sobre os pontos fontes
    ci+=1
    xd=NOS[i,2]; # Coordenada x do ponto fonte
    yd=NOS[i,3]; # Coordenada y do ponto fonte
    cj=0
    for j in b2 # Laco sobre os elementos
      cj+=1
      noi::Int64=ELEM[j,2]; # Ponto inicial do elemento
      nof::Int64=ELEM[j,3]; # Ponto final do elemento
      x1=NOS_GEO[noi,2]; # Coordenada x do ponto inicial do elemento
      x2=NOS_GEO[nof,2]; # Coordenada x do ponto final do elemento
      y1=NOS_GEO[noi,3]; # Coordenada y do ponto inicial do elemento
      y2=NOS_GEO[nof,3];  # Coordenada y do ponto final do elemento
      if i==j # O ponto fonte pertence ao elemento
        g,h = calcula_HeGs(x1,y1,x2,y2,k);
      else # O ponto fonte n�o pertence ao elemento
        g,h = calcula_HeGns(x1,y1,x2,y2,xd,yd,qsi,w,k);
      end
      if CDC[j,2]==0
        G[ci,cj] = -h
        H[ci,cj] = -g
      else
        G[ci,cj] = g
        H[ci,cj] = h
      end
    end

  end
  return H,G
end

function Hinterp(Tree,block,arg,ninterp)
    # arg = [NOS,NOS_GEO,ELEM,qsi,w,CDC,k]
    #         1      2    3   4   5 6   7
    n = size(block,1)               # Quantidade de Submatrizes
    Aaca = Array{Any}(undef,n,2)          # Cria vetor{Any} que armazena submatrizes [Nº de submatrizes x 2]
    b = zeros(size(arg[1],1))       # Cria matriz b, Ax=b, de zeros [Nº de nos x 1]
    t = 0
    t1 = 0
    for i=1:n                       # Para cada Submatriz
        # @timeit to "Para cada Submatriz" begin
        b1 = Tree[block[i,1]]       # Nós I da malha que formam a submatriz (Pontos Fonte) (linhas)
        b2 = Tree[block[i,2]]       # Nós J da malha que formam a submatriz (Pontos Campo) (Colunas)
        # Submatriz = Produto cartesiano I x J
        if block[i,3]==0                # Se esses blocos não são admissiveis
            Aaca[i,1],B = cal_Aeb(b1,b2,arg)
            
            b[b1] = b[b1] + B*arg[6][b2,3] 
        else                              # Caso contrario (Se blocos são admissiveis)
            Aaca[i,1],Aaca[i,2],B=cal_Aeb_interp(b1,b2,arg,ninterp)
            b[b1] = b[b1] + Aaca[i,1]*(B*arg[6][b2,3])

        end
    end
    return Aaca,b
end

function cal_Aeb_interp(b1,b2,arg,ninterp)
    NOS,NOS_GEO,ELEM,qsi,w,CDC,k=arg
      ϵ=1e-6
nelem = size(ELEM,1)          # Numero de elementos de contorno
xmax=zeros(1,2)
xmin=zeros(1,2)
# (xmin[1],xmin[2]),(xmax[1],xmax[2]) => bounding box
xmax[1]=maximum(NOS[b1,2])
xmin[1]=minimum(NOS[b1,2])
xmax[2]=maximum(NOS[b1,3])
xmin[2]=minimum(NOS[b1,3])    
xs=criapontosinterp(ninterp)
    if(abs(xmax[1]-xmin[1])<ϵ)
        fontes=(2. .*(NOS[b1,3] .-xmin[2])./(xmax[2]-xmin[2]).-1);
        L=lagrange(fontes,xs,ninterp);
        G = zeros(ninterp,length(b2))      # Dimensiona matriz G
        H = zeros(ninterp,length(b2))      # Dimensiona matriz H
        ninterp2=ninterp
        ninterp1=1
    elseif(abs(xmax[2]-xmin[2])<ϵ)
        fontes=(2. .*(NOS[b1,2] .-xmin[1])./(xmax[1]-xmin[1]).-1);
        L=lagrange(fontes,xs,ninterp);
        G = zeros(ninterp,length(b2))      # Dimensiona matriz G
        H = zeros(ninterp,length(b2))      # Dimensiona matriz H
        ninterp2=1
        ninterp1=ninterp
    else
        fontes=[(2. .*(NOS[b1,2] .-xmin[1])./(xmax[1]-xmin[1]).-1) (2. .*(NOS[b1,3] .- xmin[2])./(xmax[2]-xmin[2]).-1)]
        L=lagrange(fontes,xs,ninterp,xs,ninterp)
        G = zeros(ninterp*ninterp,length(b2))      # Dimensiona matriz G
        H = zeros(ninterp*ninterp,length(b2))      # Dimensiona matriz H
        ninterp2=ninterp
        ninterp1=ninterp
    end
    n1,n2=calc_fforma(xs)
    xks=n1*xmin+n2*xmax
    ci=0
    for i2 =1:ninterp2 # Laco sobre os pontos de interpolação
        for i1 =1:ninterp1 # Laco sobre os pontos de interpolação
            ci+=1
            xd=xks[i1,1]; # Coordenada x do ponto fonte
            yd=xks[i2,2]; # Coordenada y do ponto fonte
            cj=0       
            for j in b2 # Laco sobre os elementos
                cj+=1
                noi::Int64=ELEM[j,2]; # Ponto inicial do elemento
                nof::Int64=ELEM[j,3]; # Ponto final do elemento
                x1=NOS_GEO[noi,2]; # Coordenada x do ponto inicial do elemento
                x2=NOS_GEO[nof,2]; # Coordenada x do ponto final do elemento
                y1=NOS_GEO[noi,3]; # Coordenada y do ponto inicial do elemento
                y2=NOS_GEO[nof,3];  # Coordenada y do ponto final do elemento
                g,h = calcula_HeGns(x1,y1,x2,y2,xd,yd,qsi,w,k);
                if CDC[j,2]==0
                    G[ci,cj] = -h
                    H[ci,cj] = -g
                else
                    G[ci,cj] = g
                    H[ci,cj] = h
                end
            end
        end
    end
    return L,H,G
end

function criapontosinterp(n)
    x= cos.((2. .*(1:n) .-1).*pi./2. ./n)
end

function lagrange(pg,x,n)
    ni = length(pg);
    L = ones(ni,n);
    for j = 1:n
        for i = 1:n
            if (i != j)
                L[:,j] = L[:,j].*(pg .- x[i])/(x[j]-x[i]);
            end
        end
    end
    return L
end

function lagrange(pg,x1,n1,x2,n2)
    l1=lagrange(pg[:,1],x1,n1)
    l2=lagrange(pg[:,2],x2,n2)
    ni=size(pg,1)
    L=zeros(ni,n1*n2)
    for i=1:ni
        L[i,:]=(l1[i,:]*l2[i,:]')[:]
    end
    return L
end

function matvec(hmat,b,block,Tree)
  v=b*0
  for i =1:length(block[:,3])
    if block[i,3]==1
      v[Tree[block[i,1]]]+=hmat[i,1]*(hmat[i,2]*b[Tree[block[i,2]]])
    else
      v[Tree[block[i,1]]]+=hmat[i,1]*b[Tree[block[i,2]]]
    end
  end
  v
end

function montacheia(hmat,block,Tree,n)
A=zeros(n,n)
  for i =1:length(block[:,3])
    if block[i,3]==1
      A[Tree[block[i,1]],Tree[block[i,2]]]=hmat[i,1]*hmat[i,2]
    else
      A[Tree[block[i,1]],Tree[block[i,2]]]=hmat[i,1]
    end
  end
  A
end
