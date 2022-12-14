### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ 1572d199-17f8-4ae3-8253-cc27e86f697f
using Images, FFTW, StatsBase

# ╔═╡ 998fcd81-b3b7-41a5-9130-9614962c4dae
using Random

# ╔═╡ 35b23d07-f643-49f4-8789-73ddbdeabdfe


# ╔═╡ a7559a22-4b4b-11ed-24f3-235b55e22f28
md"""
# IMC

## Trabajo Práctico $n^\circ 2$: Compresión de Imágenes.
"""

# ╔═╡ c979346b-cecc-4cf3-9aa6-d1d9133ab2fc
md"""Vamos a implementar una versión apenas simplificada del algoritmo de codificación de los archivos `.jpg`, que se basa en una propiedad central que vimos en  la transformada de Fourier: la transformada de señales de la vida real suele estar formada fundamentalmente por frecuencias bajas, con muy poca contribución de las frecuencias altas. Esto induce la siguiente idea: dada una señal podemos considerar su transformada y descartar todas las frecuencias por encima de un cierto umbral. Esto permite almacenar sólo un pequeño número de frecuencias, que forman la señal _comprimida_. Para recuerar la señal lo que debe hacerse es volver a completar el vector transformado con ceros y anti-transformar. 

La idea del algoritmo `jpg` es esencialmente esa, pero incluye también algunos otros trucos. En primer lugar se utiliza la transformada del coseno en lugar de la de Fourier. Las ventajas de la transformada del coseno para tareas de compresión son dos: en primer lugar es una transformada que convierte reales en reales, lo que evita el paso por los complejos (que implican almacenar dos flotantes por cada número). En segundo lugar, se observa en la práctica que en la descomposición dada por la transformada del coseno hay aún mayor concentración de información en las frecuencias bajas, lo que permite descartar más valores. La transformada del coseno está implementada en la librería `FFTW`, en el comando `dct` (discrete cosine transform). """



# ╔═╡ d7c86dc8-2a7c-4a23-8f12-8b6a17b43524
md"""### Imágenes

Los elementos básicos para operar con imágenes están en la librería `Images`. Para cargar una imagen se puede utilizar el comando `load`:"""

# ╔═╡ 1869c3d3-f224-485c-a164-da485f1a02d3
im = load("Meisje_met_de_parel.jpg") 

# ╔═╡ 9e6e8d4e-684e-4e75-beb4-15cf55a889a0
imping = load("pinguino.bmp")

# ╔═╡ 5ff81afa-eea2-4ccd-a5f6-5a81025aac46
impmandel = load("mandel.bmp")

# ╔═╡ 4b2191fb-f952-423f-8321-201e1c35ef6e
md"""La imagen se carga esencialmente como una matriz que en cada casillero tiene un elemento de tipo `RGB`:"""

# ╔═╡ f96dbd2e-de85-4855-9cfd-9f74263190e8
md"""Podemos crear nuevos elementos de tipo `RGB` con el comando `RGB()` que recibe tres números (los valores de `red`, `green` y `blue` que componen el color):"""



# ╔═╡ 71bceaf2-f149-49b0-bc9f-9a31db44219f
RGB(0.2,0.8,0.9) #los números van entre 0 (negro) y 1 (color lleno). 

# ╔═╡ 7129eaff-a7d2-46c7-9bc7-ca12bfe733c8
md"""Como la imagen es esencialmente una matriz, podemos modificarla como modificaríamos una matriz:"""



# ╔═╡ 2d21bfbd-c286-4da9-919f-c3406eb773b8
begin 
	im_adulterada = copy(im)
	im_adulterada[700:800,200:400] .= RGB(0.2,0.8,0.9)
	
	im_adulterada
end

# ╔═╡ 16835729-56db-4f74-886b-8b878c121407


# ╔═╡ ffe2070f-6c2b-4469-ab87-bf9204688f9a
md"""Existen otras codificaciones de color. A nosotros nos va a interesar la codificación `YCbCr` que está formada por una componente de luminosidad (`Y`) y dos de color (`Cb` y `Cr`). Para convertir un elemento de tipo `RGB` al formato `YCbCr` basta aplicarle `YCbCr()`:"""



# ╔═╡ 9e42d8f6-58c3-4414-8d0b-3745f8e42c34
begin
	código_rgb   = RGB(0.2,0.8,0.9)
	código_ycbcr = YCbCr(código_rgb)
	print(código_ycbcr.y) #el valor de la luminosidad
	print(" ")
	print(código_ycbcr.cb)
	print(" ")
	print(código_ycbcr.cr)
end

# ╔═╡ ae8cadbd-7ef7-4a2c-9f6e-2dedf8c79026
begin
	#RGB(0.2,0.8,0.9)a
	A = YCbCr(RGB(0.2,0.8,0.9))
end

# ╔═╡ 80477d11-0759-4043-892c-4fba4a07ef3e
RGB(A).b

# ╔═╡ 373dc480-9a64-4f94-b42d-0145427f95f8
md"""### El algoritmo

#### Preparación

Nuestro algoritmo asumirá que las dimensiones de la imagen son divisibles por 16. Para simplificar la implementación, haremos un primer paso que consistirá en rellenar los márgenes de la imagen con negro hasta lograr que ambas dimensiones sean múltiplos de 16. Por ejemplo: si un imagen tiene 37 píxeles de ancho queremos agregarle una banda de 5 píxeles negros a la izquierda y otra  de 6 a la derecha, hasta tener 48 píxeles. Este proceso no es óptimo y puede generar artefactos indeseados en la imagen comprimida, pero es la variante más simple. 

Implementar una función que realice este proceso."""

# ╔═╡ d8af8572-a4fe-4553-8801-2bf68c299076
begin
	# preparación
	function dameSiguientePotenciaDe2(numero) #ESTA FUNCION NO SE USA NI SE USARA
		return 2^Int(floor(log(2,numero))+1)
	end
	function longPretendidaMultiplo16(numero)
		if(numero%16 != 0)
			return numero + 16 - numero%16
		end
		return numero
	end
	function rellenarImagen(imagen)
		alto = length(imagen[:,1,1])
		ancho = length(imagen[1,:,1])
		
		nuevoAlto = longPretendidaMultiplo16(alto)
		nuevoAncho = longPretendidaMultiplo16(ancho)
		
		im_ampliada = RGB.(zeros(nuevoAlto, nuevoAncho))
		for i in 1:alto
			for j in 1:ancho
				for k in 1:3
					im_ampliada[i,j] = imagen[i,j]
				end
			end
		end
		return im_ampliada
	end
end

# ╔═╡ e963606c-b88e-4bca-bcbb-7d4e7269aa56
dameSiguientePotenciaDe2(100)

# ╔═╡ 1a5d9f8e-4a11-4b68-a53b-2f3e4928680b
longPretendidaMultiplo16(80)

# ╔═╡ d1187154-b075-4743-8a4e-570ce37c6f66
alto = length(im[:,1,1])

# ╔═╡ eb09da2b-cdfb-4fca-8bae-e154a008d974
ancho = length(im[1,:,1])

# ╔═╡ 93debb01-597c-4c88-adf4-9394e7664742
imgamp = rellenarImagen(im)


# ╔═╡ 37012fb7-a9c1-4c42-a732-41b00bae0eaf
imgpingamp = rellenarImagen(imping)

# ╔═╡ 36e56fba-a298-4e1f-bfc6-9699ea77f8e0
imgmandamp = rellenarImagen(impmandel)

# ╔═╡ 10d51d37-62c6-43b5-9a82-21e591b60e9f
altonu = length(imgamp[:,1,1])


# ╔═╡ 412eda17-2710-4728-b38b-fb86a8a43c48
anchonu = length(imgamp[1,:,1])

# ╔═╡ c2c7bcb5-1a43-4608-9eef-2fe235536b5d
im[3500,3300]

# ╔═╡ e8feb188-8f86-429d-a301-5a8097aa4121
md"""#### Primera etapa

En algoritmo trabaja sobre la descomposición `YCbCr`, por lo cual lo primero que hay que hacer es convertir la imagen a este formato. Además, necesitamos separar los tres canales para operar sobre ellos por separado. Esto se logra con el comando `channelview` que convierte una imagen de `n×m` pixels en un arreglo `A` de `3×n×m`. De esta manera `A[1,:,:]` corresponderá al canal  `Y`, etc. 

Finalmente: dado que el ojo humano es mucho más sensible a la luminosidad que a la intensidad de color, podemos reducir las matrices `Cb` y `Cr`. Para ellos generaremos nuevas matrices de tamaño `n/2×m/2` en las que cada pixel sea el promedio de `4` pixels vecinos en la matriz original. Por último, haremos un corrimiento en los coeficientes de todas las matrices para que éstos queden centrados en 0. Dado que nuestra codificación arrojará valores entre 0 y 255, lo que hacemos es restar 128 en cada casillero. 

Implementar una función que reciba una imagen y realice todo este proceso, devolviendo una matriz numérica `Y` de `n×m` y matrices numéricas `Cb`y `Cr` de tamaño la mitad en cada dimensión. 

Implementar también el proceso inverso que consiste en, dadas tres matrices como las anteriores, sumarles 128, ampliar `Cb` y `Cr` (generando `4` pixels iguales por cada pixel original), reensamblarlas en una imagen `YCbCr` y finalmente convertirla a `RGB`. Aquí es necesario el comando `colorview` que recibe un tipo de dato (en este caso `YCbCr`) y un arreglo de `3×n×m` y devuelve la imagen."""                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        

# ╔═╡ 41bf4d45-04ca-453e-829b-08a4d699f0c8
# etapa 1
function descomposicionYCbCr(imagen)
		alto = length(imagen[:,1,1])
		ancho = length(imagen[1,:,1])

		brillo = zeros(alto, ancho)
		imCb = zeros(Int(alto/2), Int(ancho/2))
		imCr = zeros(Int(alto/2), Int(ancho/2))
		for i in 1:alto
			for j in 1:ancho
				código_ycbcr = YCbCr(imagen[i,j])	
				brillo[i,j] = código_ycbcr.y
			end
		end
		for i in 1:Int(alto/2)
			for j in 1:Int(ancho/2)
				izqarr= YCbCr(imagen[2*i,2*j])
				if 2*j<ancho
					derarr= YCbCr(imagen[2*i,2*j+1])
				else
					derarr = YCbCr(imagen[2*i,2*j])
				end
				if 2*i<alto
					izqaba= YCbCr(imagen[2*i+1,2*j])
				else
					izqaba = YCbCr(imagen[2*i,2*j])
				end
				if 2*j<ancho & 2*i<alto
					deraba= YCbCr(imagen[2*i+1,2*j+1])
				else
					deraba= YCbCr(imagen[2*i,2*j])
				end
				imCb[i,j] = (izqarr.cb+derarr.cb+izqaba.cb+deraba.cb)/4
				imCr[i,j] = (izqarr.cr+derarr.cr+izqaba.cr+deraba.cr)/4
			end
		end
		imCb = imCb .- 128
		imCr = imCr .- 128
		return brillo, imCb, imCr
	end

# ╔═╡ 5f794d76-2530-4c60-a670-894e86fc0ed8
begin
	descompuesta = descomposicionYCbCr(imgamp)
	descompuestaPing = descomposicionYCbCr(imgpingamp)
	descompuestaMand = descomposicionYCbCr(imgmandamp)
end

# ╔═╡ 90365b61-b2d7-4a4f-b529-f3cdac94a795
# inversa de etapa 1
function recomposicionRGB(tuplaMat)
		brillo, cb, cr = tuplaMat
		alto = length(brillo[:,1,1])
		ancho = length(brillo[1,:,1])
		
		imagen = RGB.(zeros(alto, ancho))
		cb = cb .+ 128
		cr = cr .+ 128
		for i in 1:alto
			for j in 1:ancho
				luz = brillo[i,j]
				cbpix = cb[max(Int(floor(i/2)),1),max(Int(floor(j/2)),1)]
				crpix = cr[max(1,Int(floor(i/2))),max(1,Int(floor(j/2)))]
				
				código_rgb = RGB(YCbCr(luz, cbpix, crpix))
				imagen[i,j] = código_rgb
			end
		end
		return imagen
	end

# ╔═╡ 99d400ec-0b81-4a26-b21b-c45f1671e40f
recomposicionRGB(descompuesta)

# ╔═╡ 2761a1c6-e56f-4676-a7ea-f66054a5c7f7
recomposicionRGB(descompuestaPing)

# ╔═╡ d981fd7d-1455-47c8-9f82-325f70f9dcc7
recomposicionRGB(descompuestaMand)

# ╔═╡ debe5314-fd82-4af3-b1f7-73772025016b
md"""#### Transformada por bloques

El siguiente paso consiste en pensar a cada matriz como una agrupación de bloques de `8×8` y en cada uno de estos bloques aplicar la transformada del coseno discreta (`dct`). El resultado de esta etapa son las 3 matrices transformadas por bloques. Para ahorrar memoria pueden utilizarse los comandos `view` (que permite acceder y modificar en el lugar secciones de matrices) y `dct!` (que aplica la transformada modificando su argumento). 

Implementar esta función y su inversa, que debe aplicar `idct` (o `idct!`) por bloques."""  

# ╔═╡ 56169522-8fab-454b-a167-551e03d91228
function transformarMatriz(matrix)
	alto  = length(matrix[1,:])
	ancho = length(matrix[:,1])
	matrizcopia = copy(matrix)
	for i in 1:8:ancho
		for j in 1:8:alto
			matrizcopia[i:i+7,j:j+7]  = dct(matrizcopia[i:i+7,j:j+7])
			end
		end
	return matrizcopia
end


# ╔═╡ 89a20ba2-2867-439e-a1cb-f9d4ec74fe05
function transformarImagen(tuplaMatrices)
	mat1trans = transformarMatriz(tuplaMatrices[1])
	mat2trans = transformarMatriz(tuplaMatrices[2])
	mat3trans = transformarMatriz(tuplaMatrices[3])
	return(mat1trans, mat2trans, mat3trans)
end

# ╔═╡ 71b25a7b-1c7f-4772-82d9-168520fb917d
# inversa
function antitransformarMatriz(matrix)
	alto  = length(matrix[1,:])
	ancho = length(matrix[:,1])
	matrizcopia = copy(Float64.(matrix))
	for i in 1:8:ancho
		for j in 1:8:alto
			matrizcopia[i:i+7,j:j+7]  = (idct(matrizcopia[i:i+7,j:j+7]))
			end
		end
	return matrizcopia
end


# ╔═╡ 41fef68a-63ff-47d5-b909-f279dc65bb10
function AntitransformarImagen(tuplaMatrices)
	mat1trans = antitransformarMatriz(tuplaMatrices[1])
	mat2trans = antitransformarMatriz(tuplaMatrices[2])
	mat3trans = antitransformarMatriz(tuplaMatrices[3])
	return(mat1trans, mat2trans, mat3trans)
end

# ╔═╡ be3adadd-828c-4a6f-bd01-272a3d1b3599
transformadaPinguino = transformarImagen(descompuestaPing)

# ╔═╡ 0f6327b8-4b0e-4cb9-bfce-e6dc419c53a5
antitransPinguino =  AntitransformarImagen(transformadaPinguino)

# ╔═╡ e3c9f0cb-7f1b-45e1-90c9-103830b81aab
recomposicionRGB(antitransPinguino)

# ╔═╡ 572167ef-2fa0-4354-843d-0d9e92c42f00
recomposicionRGB(transformadaPinguino)

# ╔═╡ 61d8b3f0-d67d-4278-b19e-3e33686e8c45
md"""#### Cuantización

En esta etapa se realiza la compresión más importante. Esencialmente, se trata de descartar las frecuencias altas en cada bloque de `8×8`. Esto se hace a través de una matriz de _cuantización_. La `dct` descompone en frecuencias positivas, por lo cual al transformar una de nuestras matrices la frecuencia 0 se encuentra en el casillero `[1,1]` y la frecuencia más grande en el casillero `[8,8]`. Una matriz de cuantización será una matriz de enteros fija de `8×8`, simétrica, que tendrá típicamente valores chicos en el casillero `[1,1]` y valores cada vez más altos a medida que nos aproximamos al casillero `[8,8]`. La siguiente matriz es un posible ejemplo: """

# ╔═╡ 33cc2c7e-b6b5-4ca0-94c3-8f89f3312af4
quant=[16 11 10 16 24 40 51 61; 
   12 12 14 19 26 58 60 55; 
   14 13 16 24 40 57 69 56; 
   14 17 22 29 51 87 80 62;
   18 22 37 56 68 109 103 77;
   24 35 55 64 81 104 113 92; 
   49 64 78 87 103 121 120 101;
	72 92 95 98 112 100 103 99]

# ╔═╡ 49e94ada-2149-4af0-9b32-fbfaa75a74a3
md"""El proceso de cuantización consiste en tomar cada bloque de cada una de las tres matrices de la imagen y dividirlo casillero a casillero por la matriz de  cuantización, redondeando el resultado. Por ejemplo, si un bloque es: """

# ╔═╡ a72a54fe-18d2-44b4-8f77-1d1f0ea8dcb1
bloque =  [-520.7 180.3 -91.9 15.1 28.7 10 1 2;
		   172.2 -137 87  5  0  1 0 3;
		    79.5  -63 -55.4 13.6 10  5 0 0;
			51  32 38  -7.3  8  2 0 1;
			29  18 -10  5.8  1  0 2 0;
			-17   6  3  1  2  0 0 0.8;
			 9   2  1  2.2  0.3  1.1 3 5;
			 3   -1  0.7  0  0  1 0 2.1]

# ╔═╡ 60563a9e-628b-4fe4-bedd-2573a33e9f77
md"""La correspondiente cuantización será algo como lo siguiente:"""

# ╔═╡ 8776f24a-80b2-4611-8480-2b0e50b7cec8
bloque_cuant = Int.(round.(bloque./quant))

# ╔═╡ 772b05e0-7063-4d31-add5-b1f1905df558
md"""Como se observa, el resultado tiene muchos ceros que tienden a acumularse en las últimas columnas y filas. Esto ayudará a realizar la compresión en el siguiente paso.

Implementar una función que realice el proceso de cuantización sobre una matriz.

Implementar también el proceso inverso, que consiste en multiplicar por la matriz de cuantización casillero a casillero."""

# ╔═╡ a7c04406-82b0-488d-9b4e-ada252579ab5
# cuantización
function quantizacion(tuplaMatrices, quantMatriz)
	matrizcopia1 = zeros(Int, length(tuplaMatrices[1][:,1]), length(tuplaMatrices[1][1,:]))#copy(tuplaMatrices[1])
	matrizcopia2 = zeros(Int, length(tuplaMatrices[2][:,1]), length(tuplaMatrices[2][1,:]))  #copy(tuplaMatrices[2])
	matrizcopia3 = zeros(Int, length(tuplaMatrices[3][:,1]), length(tuplaMatrices[3][1,:])) #copy(tuplaMatrices[3])
	copiasMat = (matrizcopia1,matrizcopia2,matrizcopia3) 
	for matrizIesima in 1:3
		alto  = length(tuplaMatrices[matrizIesima][1,:])
		ancho = length(tuplaMatrices[matrizIesima][:,1])
		for i in 1:8:ancho
			for j in 1:8:alto
				bloque = tuplaMatrices[matrizIesima][i:i+7,j:j+7]
				bloque_cuant = Int.(round.(bloque./quantMatriz))
				copiasMat[matrizIesima][i:i+7,j:j+7]  = bloque_cuant
			end
		end
	end
	return (copiasMat)
end

# ╔═╡ 615a9812-f192-443d-9bd1-c2b7a625e7ed
# inv-cuantización
function invquantizacion(tuplaMatrices, quantMatriz)
	matrizcopia1 = copy(tuplaMatrices[1])
	matrizcopia2 = copy(tuplaMatrices[2])
	matrizcopia3 = copy(tuplaMatrices[3])
	copiasMat = (matrizcopia1,matrizcopia2,matrizcopia3) 
	for matrizIesima in 1:3
		alto  = length(tuplaMatrices[matrizIesima][1,:])
		ancho = length(tuplaMatrices[matrizIesima][:,1])
		for i in 1:8:ancho
			for j in 1:8:alto
				bloque = copiasMat[matrizIesima][i:i+7,j:j+7]
				bloque_cuant = Int.(round.(bloque.*quantMatriz))
				copiasMat[matrizIesima][i:i+7,j:j+7]  = bloque_cuant
			end
		end
	end
	return (copiasMat) # HAY QUE ENTERIZARLO
end

# ╔═╡ 1e38093f-717f-474f-8e3c-cf2bac18099c
assd = quantizacion(descompuesta, quant)

# ╔═╡ b4882722-099e-43d5-86b7-39da98f1c12f
invs = invquantizacion(assd, quant)

# ╔═╡ 79d9b448-1220-48da-b314-53c005869351
recomposicionRGB(assd)

# ╔═╡ e687ca73-1546-4c1b-b0ff-04ed86fc299d
recomposicionRGB(invs)

# ╔═╡ e9d33e31-aace-47f3-bda6-7e422f4a507d
recomposicionRGB(descompuesta)

# ╔═╡ 4a893d28-4023-4c51-a1b9-47c812097da7
md"""Observar que al aplicar la cuantización y su inversa el resultado es que se convierten en 0 muchos de los valores, pero los otros se preservan aproximadamente iguales (salvo error de redondeo)."""



# ╔═╡ 603cc8ce-2702-46ad-95c3-2931c646958f
md"""#### Compresión

Finalmente, llegamos al momento de descartar los ceros de los bloques transformados. Para ello aplicaremos el siguiente procedimiento:

1. Leeremos cada bloque en zig-zag, convirtiéndolo en un vector. El orden de lectura es:

	[1,1],[1,2],[2,1],[3,1],[2,2],[1,3],[1,4],...,[8,6],[7,7],[6,8],[7,8],[8,7],[8,8] 

Observar que de esta manera tendremos que casi siempre la cola del vector está formada por ceros.  Es decir que si se tiene la matriz: 

"""







# ╔═╡ 89ba95b9-6c06-4732-9b38-94448595d51d
mat_ejemplo = reshape(1:64,8,8)

# ╔═╡ 5af7c99f-906d-4642-b060-a53856bdb5cb
function damediag(mat, ndiag)
	if ndiag<=8
		i = ndiag
		j = 1
	else
		i = 8
		j = ndiag-8
	end
	vec = []
	while(i>=1 && j<= length(mat[1,:]) && j>=1 && i<= length(mat[1,:]))#& j>=1 & i<= 
		push!(vec, mat[j, i])
		j = j + 1
		i = i -1
	end
	return vec
end

# ╔═╡ 68a5bf30-ca28-4ca3-ba60-6b031124f0fa
function ponerdiag(mat, ndiag, vec)
	mat2 = copy(mat)
	if ndiag<=8
		i = ndiag
		j = 1
	else
		i = 8
		j = ndiag-8+1
	end
	for h in 1:length(vec)
		mat2[j, i] = vec[h]
		j = j + 1
		i = i -1
	end
	return mat2
end

# ╔═╡ 960e9ddf-9ca6-4bdf-8356-23bb05217b23
ponerdiag(mat_ejemplo, 9, [-100, 99,77,66,55,100,100])

# ╔═╡ a716593f-9050-47ce-a8c7-93c82b5e6dd4
function generarVectorzigzag(mat)
	vectotal = []
	for i in 1:16
		vec1 = damediag(mat,i)
		if(i<=8)
			if(i%2==1)
				vectotal = vcat(vectotal, reverse(vec1))
			else
				vectotal = vcat(vectotal, vec1)
			end
		else
			if(i%2==0)
				vectotal = vcat(vectotal, reverse(vec1))
			else
				vectotal = vcat(vectotal, vec1)
			end
		end
	end
	ix_drop = 37:44
	vectotal = deleteat!(vectotal,ix_drop)
	return (vectotal)
end

# ╔═╡ d2d7fb19-f3c6-4c82-b662-a32b5d9fe11d
vmat = generarVectorzigzag(mat_ejemplo)

# ╔═╡ f270e723-ead0-4d04-8455-5cd2bf17b9c3
function generarMatrizDesdeVectorZigZag(vectorazo)
	longitudes = [1,2,3,4,5,6,7,8,7,6,5,4,3,2,1]
	mat = zeros(8,8)
	actual = 1
	for h in 1:length(longitudes)
		diag = vectorazo[actual: actual + longitudes[h]-1]
		actual = actual + longitudes[h]
		#print(diag)
		if(h%2==0)
			mat = ponerdiag(mat, h, diag)
		else
			mat = ponerdiag(mat, h, reverse(diag))
		end
	end
	return mat
end

# ╔═╡ 29d2d8f7-3b4f-4817-9cb6-95186a4da0da
matTransf =  Int.(generarMatrizDesdeVectorZigZag(vmat))

# ╔═╡ 0362c20f-fa97-42eb-b0af-1e2332ee42c5
vmat[2:3]

# ╔═╡ cdeabb5f-9c87-4346-ab38-c86f408189bc
md"""El orden de lectura debería ser: 
	1,9,2,3,10,17,25,18,11,4,...,48,55,62,63,56,64

Vale la pena tener en cuenta que Julia admite indexar una matriz como si fuera un vector, en cuyo caso la lee por columnas:"""

# ╔═╡ 5e013596-c983-4486-8853-7607031be4a3
mat_ejemplo[9]

# ╔═╡ 8008b883-3adc-480f-8aff-620382e49603
md"""2. El vector resultante lo comprimiremos haciendo uso del método _Run Length Encoding_ que consiste en indicar la cantidad de veces consecutivas que se repite un número, y el número. De esta manera, la tira `[3,3,3,3,3]` se codificaría con un `3` y un `5` (dos números en lugar de cinco). Felizmente esto está implementado en la librería `StatsBase` en la función `rle`:""" 

# ╔═╡ f1465ba4-4ca8-4d41-a678-cf9f593a6b57
begin
	vector_test = [1,1,1,1,0,0,1,1,0,0,0,0,2,0,0,0,0]
	vals,reps   = rle(vector_test)
end

# ╔═╡ 84ddff11-ae06-4bcb-82ab-06e54cbf241d
reps

# ╔═╡ 18014b47-f08b-4aed-abb8-d0a7b71f9614
vals

# ╔═╡ 511170ac-e9fa-4136-b5f8-6c08126ad297
md"""También existe la inversa:"""

# ╔═╡ f03504e3-9862-4a2e-8525-9b2df88dfcd3
inverse_rle(vals,reps)

# ╔═╡ 8554d36c-5975-42cb-b8cb-56741097d071


# ╔═╡ 66e99f7f-3d1b-4fdc-ac24-4d30c535d654
md"""Por último, haremos un largo vector en el que almacenaremos todos estos números. Observar que tendremos un par de vectores (repeticiones y valores) por cada bloque de cada matriz. Podemos generar un vector de vectores de la forma `[reps₁,vals₁,reps₂,vals₂,...]`, o directamente poner todos los números en una sola tira. En el siguiente paso grabaremos esto en un archivo, y allí no habrá vectores sino sólo una larga tira de números. 

Puede resultar más simple hacer una función que procese sólo una matriz y genere la tira de datos que le corresponde y luego otra que simplemente concatene las tres tiras."""

# ╔═╡ 2191cb16-01a7-4f7f-9019-413dc5d52cdc
md"""Implementar la función que genera este vector. 

Implementar también su inversa que debe tomar la larga tira de datos y separarla en 3 trozos de tamaño adecuado, y cada trozo en parejas (repeticiones y valores) por bloque, que luego deben reensamblarse (con `inverse_rle`) y acomodarse en la matriz correspondiente."""

# ╔═╡ 6ac98964-92e0-4cf3-a004-51194f17ee73
# compresion
# compresion
# Recibe una matriz y a sus submatrices de 8x8 las las escribe como formato
# [reps₁,vals₁,reps₂,vals₂,...]

function compresion(matrix)
	alto  = length(matrix[:,1])
	ancho = length(matrix[1,:])
	res = []
	for i in 1:8:Int(alto)
		for j in 1:8:Int(ancho)
			vals,reps = rle(generarVectorzigzag(matrix[i:i+7,j:j+7]))
			
			push!(res,reps)
			push!(res,vals)
		end
	end
	return res, alto, ancho
end

# ╔═╡ 1fe0ba5e-84da-4b57-8aa6-0d946b1b78ee
function compresionImagen(tuplaMatrices)
	resultados1 = compresion(tuplaMatrices[1])
	resultados2 = compresion(tuplaMatrices[2])
	resultados3 = compresion(tuplaMatrices[3])
	return(resultados1,resultados2, resultados3)
end

# ╔═╡ 86ad4a83-44c1-4ce6-a820-e858d9ef5724
function decompresion2(vec, alto, ancho)
	matrix = zeros(alto, ancho)
	jAlto = 1 
	kAncho = 1
	for i in 1:2:Int(length(vec))
		reps = Int.(vec[i])	
		vals = Int.(vec[i+1])
			
		vmat = inverse_rle(vals,reps)
		matTransf =  (generarMatrizDesdeVectorZigZag(vmat))
			
		matrix[jAlto:jAlto+7,kAncho:kAncho+7] .= matTransf
		
		kAncho = kAncho + 8
		if(kAncho>=ancho)
			kAncho = 1
			jAlto= jAlto+8
		end
	end
	return matrix
end

# ╔═╡ 75801208-efa8-4a3e-b70b-4945727c0c48
function decompresionImagen(tuplaComprimidas)
	resultados1 = decompresion2(tuplaComprimidas[1][1],tuplaComprimidas[1][2],tuplaComprimidas[1][3])
	resultados2 = decompresion2(tuplaComprimidas[2][1],tuplaComprimidas[2][2],tuplaComprimidas[2][3])
	resultados3 = decompresion2(tuplaComprimidas[3][1],tuplaComprimidas[3][2],tuplaComprimidas[3][3])
	return(resultados1,resultados2, resultados3)
end

# ╔═╡ 753f9f6b-7244-418c-9df7-3c33a7194270
md""" #### Guardado

Por último, queremos almacenar nuestra tira de datos en un archivo que representará el formato comprimido. 

Para esto resultarán útiles los siguientes comandos:

 * Para abrir un archivo (y crearlo si no existe):

	io = open("nombre.ext","w")

Esto genera una variable `io` de tipo `IOStream` (input-output stream), que contiene todo lo que tiene el archivo. Si se quiere abrir el archivo sólo para leerlo, se omite la `"w"`.

 * Para escribir un número `num` sobre el archivo abierto:

	write(io,num)

 * Para cerrar el archivo (esto es muy importante para que el archivo se guarde):

	close(io)

 * Para leer hay varias formas. El comando `read` aplicado a `io` devolverá un vector con todos los bytes en formato hexadecimal. Más práctico es utilizar `read` indicando el tipo de dato que se espera obtener. Esto leerá la cantidad necesaria de bytes y devolverá el tipo de dato deseado. Además, el _cabezal de lectura_ queda ubicado en la última posición por lo cual la siguiente aplicación de `read` leerá los siguientes bytes. Por ejemplo: 

    a =	read(io,Int64)

lee 8 bytes y los devuelve como número entero, que se guarda en `a`. Si luego se ejecuta:

	b = read(io,Int8)

se leerá el noveno byte del archivo como un entero y se lo guardará en `b`. """


# ╔═╡ c1e49703-7873-4955-8bc5-35cda63c2166
UInt8(126)

# ╔═╡ 2758a0f4-56be-428d-8997-b4c35ff73e25
md"""##### Nota sobre tipos:

Una imagen en formato `RGB` típicamente se codifica en enteros entre 0 y 255, cuyo formato es `UInt8` (unsigned integer, 8 bits). Julia utiliza el formato (equivalente) `N0f8` que representa flotantes entre 0 y 1 de la forma $\frac{k}{255}$ con $k=0,\dots,255$. Esto es importante porque si se utilizaran flotantes de tipo `Float64` o enteros `Int64` cada número ocuparía 8 bytes en lugar de 1, y el tamaño total del archivo sería 8 veces el necesario. 

Para generar nuestro pseudo-jpg debemos tener esto en cuenta. Los datos del `RGB` vendrán en `N0f8`, que se convertirán en flotantes entre 0 y 255 al pasar a `YCbCr`. Al restar 128, pasaremos al rango entre -128 y 127, pero seguiremos teniendo flotantes Podríamos redondearlos y pasarlos a  `Int8`. Sin embaro, al aplicar `dct` obtendremos flotantes en un rango mayor. Este proceso típicamente se revierte al aplicar la cuantización. Los valores redondeados de la matriz cuantizada pueden almcenarse como `Int8`, ocupando sólo 1 byte cada uno. El objetivo es guardarlos de esta manera en el archivo. """


# ╔═╡ b25eb87f-09bb-44af-81c5-9f2e5905e59f
md""" Implementar una función que guarde en un archivo la siguiente información:
 1. las dimensiones de la imagen: dos númerosn, `n` y `m`, en formato `UInt16` (las necesitaremos para reconstruir la imagen). 
 2. La matriz de cuantización utilizada: 64 números en formato `UInt8`. 
 3. La tira de datos que codifica con _Run Length Encoding_  la información para reconstruir las matrices: muchos números, en formato `Int8`. 

Implementar también la función inversa, que debe leer el archivo y devolver las dimensiones, la matriz de cuantización y la tira de datos que permite reconstruir las matrices.

Los distintos formatos de archivo utilizan marcadores para identificar el inicio o fin de ciertos bloques de información. Por ejemplo: se reserva un código hexadecimal especial para indicar el inicio de la matriz de cuantización y otro para el inicio de los datos que codifican las matrices, etc. Esto permite introducir ciertas variaciones en el formato manteniéndolo compatible con cualquier lector. El lector no esperará que la matriz de cuantización comience en el tercer _casillero_ del archivo, sino que la buscará a continuación del marcador estándar. Nosotros hacemos algo más casero: nuestro formato quedará determinado secuencialmente y sólo es posible leerlo conociendo a priori los distintos tipos de datos que se utilizaron. """

# ╔═╡ ef5d2e2c-4677-443d-8f96-a7cbea0795be
# guardado
function guardado(compresion, nombre)
	comp1, comp2, comp3 = compresion
	alto = comp1[2]
	ancho = comp1[3]
	io = open(nombre,"w")
	write(io,UInt16(alto))
	write(io,UInt16(ancho))
	for i in 1:3
		for j in 1:2:length(compresion[i][1])
			
			for k in 1:length(compresion[i][1][j])
				write(io,Int8(compresion[i][1][j][k]))
			end
			for k in 1:length(compresion[i][1][j])
				write(io,Int8(compresion[i][1][j+1][k]))
			end
		end
	end
	close(io)

	return comp1
end

# ╔═╡ 897fd073-5eea-4f2c-850d-7073a7ed0b2e
function desguardado(nombre)
	io2 = open(nombre,"r")
	lista = Int.(read(io2))
	for i in 5:length(lista)
		if(lista[i]>128)
			lista[i] = lista[i] -256
		end
	end
		
	altoReal =lista[1]*1 + lista[2]*256
	anchoReal =lista[3]*1 + lista[4]*256
	mat1 = []
	mat2 = []
	mat3 = []
	tamanioLista1 = altoReal*anchoReal/64

	tamanioLista23 = altoReal/2*anchoReal/2 / 64
	cantidadPegos = 0
	j = 5
	while (j<=length(lista))
		suma = 0
		cantInd = 0
		repaux = []
		valsaux = []
		while (suma < 64)
			
			push!(repaux, lista[j])
			suma = suma + lista[j]
			j = j + 1
			cantInd = cantInd + 1
		end
		while (cantInd > 0)
			push!(valsaux, lista[j])
			j = j + 1
			cantInd = cantInd - 1
		end
		
		if(cantidadPegos<tamanioLista1)
			push!(mat1, repaux)
			push!(mat1, valsaux)
			cantidadPegos = cantidadPegos + 1

		elseif(cantidadPegos<tamanioLista1+tamanioLista23)
			push!(mat2, repaux)
			push!(mat2, valsaux)
			cantidadPegos = cantidadPegos + 1
		else
			push!(mat3, repaux)
			push!(mat3, valsaux)
			cantidadPegos = cantidadPegos + 1
		end
	end
	mat11 = (mat1, altoReal, anchoReal)
	mat22 = (mat2, Int(altoReal/2), Int(anchoReal/2))
	mat33 = (mat3, Int(altoReal/2), Int(anchoReal/2))
	tuplaMatComp = (mat11, mat22, mat33)
	return tuplaMatComp
end

# ╔═╡ 04667800-3b83-4994-9cd4-74e42b724373
# lectura

# ╔═╡ 57f662e0-cbcb-4042-b2c7-36db10246610
md"""##### Nota: 

El algoritmo `jpg` tiene un paso más antes del guardado que consiste en codificar los vectores que nosotros generamos mediante un código de Huffman. Este código transcribe la información en formato binario, optimizando la longitud de los "símbolos" que la componen. Nosotros nos estamos salteando ese paso, que permitiría mejorar un poco más la compresión. Una consecuencia de esto es que nuestros archivos no serán verdaderos `.jpg`, sino un nuevo formato que podremos interpretar gracias a las funciones inversas que permiten revertir el proceso. """

# ╔═╡ 63ca201c-3de7-490b-a243-20bfbaaea5ed
md"""#### Todo junto

Ya tenemos todos los elementos. Sólo resta implementar dos funciones que junten todo lo anterior. La primera debe recibir el el nombre de archivo de imagen, cargarlo,  hacer la compresión y guardarla en un nuevo archivo con el mismo nombre y alguna extensión ficticia. La segunda debe recibir un archivo comprimido y realizar el proceso inverso al de compresión y devolver la imagen (de modo de poder verla dentro de Julia). """

# ╔═╡ 1d8e5cb3-60f2-4292-89c1-550c45c48a3c
quant1=[16 11 10 16 24 40 51 61; 
   12 12 14 19 26 58 60 55; 
   14 13 16 24 40 57 69 56; 
   14 17 22 29 51 87 80 62;
   18 22 37 56 68 109 103 77;
   24 35 55 64 81 104 113 92; 
   49 64 78 87 103 121 120 101;
	72 92 95 98 112 100 103 99]

# ╔═╡ f4d4135a-c22a-4571-b5bc-bb4c5d0ff03d
quant2 = [15 11 10 16 24 40 49 59; 
   12 11 14 19 26 58 60 55; 
   14 13 15 24 40 57 69 56; 
   14 17 22 27 51 87 80 62;
   16 22 37 56 66 109 103 77;
   22 35 55 64 81 105 113 92; 
   42 64 78 87 103 121 122 100;
	73 98 95 98 112 99 101 97]

# ╔═╡ 78e97c71-62c2-49fb-a318-12e760eb1e4c
begin
	quant3= 99 * ones(8,8)
	quant3[1:4, 1:4] .= [17 18 24 47;
						18 21 26 66;
						24 26 56 99;
						47 66 99 99]
end

# ╔═╡ 1954d1af-732c-4da5-b43b-1105f35dc814
# codificación
function codificacion(nombreArchivoOriginal, nombreArchivoComprimido, quant)
	imagenOriginal = load(nombreArchivoOriginal)
	comprimidafull = compresionImagen(quantizacion(transformarImagen(descomposicionYCbCr(rellenarImagen(imagenOriginal))), quant))
	guardado(comprimidafull, nombreArchivoComprimido)
end

# ╔═╡ 00f33b38-5ad5-4c37-8a22-0501298ff7ae
# decodificación
function decodificacion(nombreArchivoComprimido, quant)
	comprimida = desguardado(nombreArchivoComprimido)
	decompresionfull2 =  recomposicionRGB(AntitransformarImagen(invquantizacion(decompresionImagen(comprimida), quant))) 
	return decompresionfull2
end

# ╔═╡ badf936c-98d2-4e72-a138-260e081fb190
codificacion("Meisje_met_de_parel.jpg", "pesada.AxelTomiMandan", quant1)

# ╔═╡ fd599b11-dda7-4691-aa94-493b68933685
decodificacion("pesada.AxelTomiMandan", quant1)

# ╔═╡ 53918244-e558-49ac-9456-ed7f0d7782a1
md"""#### Pruebas:

Probar la compresión con un par de imágenes a elección. Si es posible, busquen imágenes en formato `.bmp` (sin comprimir). Si utilizan imágenes  `.jpg` seguramente no obtendrán archivos más chicos. En tal caso es mejor partir de imágenes de alta calidad (que dejen margen para comprimir un poco más). En importante tener en cuenta que distintas matrices de cuantización darán lugar a distintos grados de compresión. Probar al menos dos matrices de cuantización. """

# ╔═╡ a029a74d-2da9-4d62-8a60-c7cef563d664
codificacion("pinguino.bmp", "pingquant1.AxelTomiMandan", quant1)

# ╔═╡ 8daf55c2-2d80-426b-9b1e-872daf9e61d4
decodificacion("pingquant1.AxelTomiMandan", quant1)

# ╔═╡ 88d67866-9672-496f-90ec-269e5f7ace26
codificacion("pinguino.bmp", "pingquant2.AxelTomiMandan", quant2)

# ╔═╡ 5fda9ff0-ccf3-470a-9770-c4054bffefb0
decodificacion("pingquant2.AxelTomiMandan", quant2)

# ╔═╡ 5cded9ce-5bcd-4e4d-bc01-d6856d32024d
codificacion("pinguino.bmp", "pingquant3.AxelTomiMandan", quant3)

# ╔═╡ a8319bc2-5175-438a-aa03-2a95b4be3ed6
decodificacion("pingquant3.AxelTomiMandan", quant3)

# ╔═╡ 1d818865-534c-4610-9e08-81cf13ef8183
codificacion("snail.bmp", "snailquant1.AxelTomiMandan", quant1)

# ╔═╡ 871968d6-22bd-45ba-8340-eab8deda0696
decodificacion("snailquant1.AxelTomiMandan", quant1)

# ╔═╡ 04338b9f-a5c5-476e-aa6a-450c346b22f4
codificacion("snail.bmp", "snailquant2.AxelTomiMandan", quant2)

# ╔═╡ 39437ee5-3aa7-453a-b45b-6a2a440d4c1f
decodificacion("snailquant2.AxelTomiMandan", quant2)

# ╔═╡ 2efbc23c-bef9-4dd6-89f3-7aaec7167139
codificacion("snail.bmp", "snailquant3.AxelTomiMandan", quant3)

# ╔═╡ cf956f77-9292-4c91-940a-21a502c46dc3
decodificacion("snailquant3.AxelTomiMandan", quant3)

# ╔═╡ d4a5ecef-601b-4e37-a2cf-b70d0a056f9e
codificacion("Meisje_met_de_parel.jpg", "pesada3.AxelTomiMandan", quant3)

# ╔═╡ 0fb815c6-e782-45fd-bd02-1e893d39dd63
decodificacion("pesada3.AxelTomiMandan", quant3)

# ╔═╡ e733f2c6-05b7-46b9-95d6-0b482ad7d27b
recomposicionRGB(descompuesta)

# ╔═╡ f3310fac-ed65-4e75-8819-ad5f10a5f0c0
md"""
Original JPG: 6,2MB  

Pesada3(la del TP): 3,6MB

Son muy parecidas pero una pesa la mitad!
"""

# ╔═╡ 8b456277-1c55-4b2e-b3d8-222e9e03f954
codificacion("flor.bmp", "florComp3.AxelTomiMandan", quant3)

# ╔═╡ 48354c69-37d6-416a-997e-ae59b7ef74d4
codificacion("paisaje.bmp", "paisaje3.AxelTomiMandan", quant3)

# ╔═╡ d022da78-87d3-4dfe-beb6-19a7c37395b3
codificacion("paisajePeso.bmp", "paisajePeso3.AxelTomiMandan", quant3)

# ╔═╡ f6dceb5c-2c40-472b-a390-a4c66a56d70c
decodificacion("florComp3.AxelTomiMandan", quant3)

# ╔═╡ 9e2183ec-f5a4-4365-b242-0edba3f30398
decodificacion("paisaje3.AxelTomiMandan", quant3)

# ╔═╡ 5f10d16f-af26-40f8-b4f6-3c1a219e47e0
decodificacion("paisajePeso3.AxelTomiMandan", quant3)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
Images = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
FFTW = "~1.5.0"
Images = "~0.25.2"
StatsBase = "~0.33.21"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "1dd4d9f5beebac0c03446918741b1a03dc5e5788"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.6"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "80ca332f6dcb2508adba68f22f551adb2d00a624"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.3"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "75479b7df4167267d75294d14b58244695beb2ac"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.14.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "d08c20eef1f2cbc6e60fd3612ac4340b89fea322"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.9"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "924cdca592bc16f14d2f7006754a621735280b74"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.1.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "681ea870b918e7cff7111da58791d7f718067a19"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.2"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "5158c2b41018c5f7eb1470d558127ac274eca0c9"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.1"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "90630efff0894f8142308e334473eba54c433549"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.5.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "94f5101b96d2d968ace56f7f2db19d0a5f592e28"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.15.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78e2c69783c9753a91cdae88a8d432be85a2ab5e"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.0+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "db5c7e27c0d46fd824d470a3c32a4fc6c935fa96"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.7.1"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "c54b581a83008dc7f292e205f4c409ab5caa0f04"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.10"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[deps.ImageContrastAdjustment]]
deps = ["ImageCore", "ImageTransformations", "Parameters"]
git-tree-sha1 = "0d75cafa80cf22026cea21a8e6cf965295003edc"
uuid = "f332f351-ec65-5f6a-b3d1-319c6670881a"
version = "0.3.10"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[deps.ImageDistances]]
deps = ["Distances", "ImageCore", "ImageMorphology", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "b1798a4a6b9aafb530f8f0c4a7b2eb5501e2f2a3"
uuid = "51556ac3-7006-55f5-8cb3-34580c88182d"
version = "0.2.16"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "15bd05c1c0d5dbb32a9a3d7e0ad2d50dd6167189"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.1"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "342f789fd041a55166764c351da1710db97ce0e0"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.6"

[[deps.ImageMagick]]
deps = ["FileIO", "ImageCore", "ImageMagick_jll", "InteractiveUtils", "Libdl", "Pkg", "Random"]
git-tree-sha1 = "5bc1cb62e0c5f1005868358db0692c994c3a13c6"
uuid = "6218d12a-5da1-5696-b52f-db25d2ecc6d1"
version = "1.2.1"

[[deps.ImageMagick_jll]]
deps = ["Artifacts", "Ghostscript_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pkg", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "124626988534986113cfd876e3093e4a03890f58"
uuid = "c73af94c-d91f-53ed-93a7-00f77d67a9d7"
version = "6.9.12+3"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "36cbaebed194b292590cba2593da27b34763804a"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.8"

[[deps.ImageMorphology]]
deps = ["ImageCore", "LinearAlgebra", "Requires", "TiledIteration"]
git-tree-sha1 = "e7c68ab3df4a75511ba33fc5d8d9098007b579a8"
uuid = "787d08f9-d448-5407-9aad-5290dd7ab264"
version = "0.3.2"

[[deps.ImageQualityIndexes]]
deps = ["ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "LazyModules", "OffsetArrays", "Statistics"]
git-tree-sha1 = "0c703732335a75e683aec7fdfc6d5d1ebd7c596f"
uuid = "2996bd0c-7a13-11e9-2da2-2f5ce47296a9"
version = "0.3.3"

[[deps.ImageSegmentation]]
deps = ["Clustering", "DataStructures", "Distances", "Graphs", "ImageCore", "ImageFiltering", "ImageMorphology", "LinearAlgebra", "MetaGraphs", "RegionTrees", "SimpleWeightedGraphs", "StaticArrays", "Statistics"]
git-tree-sha1 = "36832067ea220818d105d718527d6ed02385bf22"
uuid = "80713f31-8817-5129-9cf8-209ff8fb23e1"
version = "1.7.0"

[[deps.ImageShow]]
deps = ["Base64", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "b563cf9ae75a635592fc73d3eb78b86220e55bd8"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.6"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "ColorVectorSpace", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "8717482f4a2108c9358e5c3ca903d3a6113badc9"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.9.5"

[[deps.Images]]
deps = ["Base64", "FileIO", "Graphics", "ImageAxes", "ImageBase", "ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "ImageIO", "ImageMagick", "ImageMetadata", "ImageMorphology", "ImageQualityIndexes", "ImageSegmentation", "ImageShow", "ImageTransformations", "IndirectArrays", "IntegralArrays", "Random", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "TiledIteration"]
git-tree-sha1 = "03d1301b7ec885b266c0f816f338368c6c0b81bd"
uuid = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
version = "0.25.2"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.IntegralArrays]]
deps = ["ColorTypes", "FixedPointNumbers", "IntervalSets"]
git-tree-sha1 = "be8e690c3973443bec584db3346ddc904d4884eb"
uuid = "1d092043-8f09-5a30-832f-7509e371ab51"
version = "0.1.5"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "64f138f9453a018c8f3562e7bae54edc059af249"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.14.4"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "57af5939800bce15980bddd2426912c4f83012d8"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.1"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "b3364212fb5d870f724876ffcd34dd8ec6d98918"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.7"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "Printf", "Reexport", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "81b9477b49402b47fbe7f7ae0b252077f53e4a08"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.22"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "a77b273f1ddec645d1b7c4fd5fb98c8f90ad10a5"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.1"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "361c2b088575b07946508f135ac556751240091c"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.17"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "e595b205efd49508358f7dc670a940c790204629"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.0.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.MetaGraphs]]
deps = ["Graphs", "JLD2", "Random"]
git-tree-sha1 = "2af69ff3c024d13bde52b34a2a7d6887d4e7b438"
uuid = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
version = "0.7.1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "0e353ed734b1747fc20cd4cba0edd9ac027eff6a"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.11"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "1ea784113a6aa054c5ebd95945fa5e52c2f378e7"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.7"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "e925a64b8585aa9f4e3047b8d2cdc3f0e79fd4e4"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.16"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "03a7a85b76381a3d04c7a1656039197e70eda03d"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.11"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.Quaternions]]
deps = ["DualNumbers", "LinearAlgebra", "Random"]
git-tree-sha1 = "b327e4db3f2202a4efafe7569fcbe409106a1f75"
uuid = "94ee1d12-ae83-5a48-8b1c-48b8ff168ae0"
version = "0.5.6"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "dc84268fe0e3335a62e315a3a7cf2afa7178a734"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.3"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RegionTrees]]
deps = ["IterTools", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "4618ed0da7a251c7f92e869ae1a19c74a7d2a7f9"
uuid = "dee08c22-ab7f-5625-9660-a9af2021b33f"
version = "0.3.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays", "Statistics"]
git-tree-sha1 = "3177100077c68060d63dd71aec209373c3ec339b"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays", "Test"]
git-tree-sha1 = "a6f404cc44d3d3b28c793ec0eb59af709d827e4e"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.2.1"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "23368a3313d12a2326ad0035f0db0c0966f438ef"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "66fe9eb253f910fe8cf161953880cfdaef01cdf0"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.0.1"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "fcf41697256f2b759de9380a7e8196d6516f0310"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.6.0"

[[deps.TiledIteration]]
deps = ["OffsetArrays"]
git-tree-sha1 = "5683455224ba92ef59db72d10690690f4a8dc297"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.3.1"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78736dab31ae7a53540a6b752efc61f77b304c5b"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.8.6+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─35b23d07-f643-49f4-8789-73ddbdeabdfe
# ╠═1572d199-17f8-4ae3-8253-cc27e86f697f
# ╟─a7559a22-4b4b-11ed-24f3-235b55e22f28
# ╟─c979346b-cecc-4cf3-9aa6-d1d9133ab2fc
# ╟─d7c86dc8-2a7c-4a23-8f12-8b6a17b43524
# ╠═1869c3d3-f224-485c-a164-da485f1a02d3
# ╠═9e6e8d4e-684e-4e75-beb4-15cf55a889a0
# ╠═5ff81afa-eea2-4ccd-a5f6-5a81025aac46
# ╟─4b2191fb-f952-423f-8321-201e1c35ef6e
# ╟─f96dbd2e-de85-4855-9cfd-9f74263190e8
# ╠═71bceaf2-f149-49b0-bc9f-9a31db44219f
# ╟─7129eaff-a7d2-46c7-9bc7-ca12bfe733c8
# ╠═2d21bfbd-c286-4da9-919f-c3406eb773b8
# ╠═16835729-56db-4f74-886b-8b878c121407
# ╟─ffe2070f-6c2b-4469-ab87-bf9204688f9a
# ╠═9e42d8f6-58c3-4414-8d0b-3745f8e42c34
# ╠═ae8cadbd-7ef7-4a2c-9f6e-2dedf8c79026
# ╠═80477d11-0759-4043-892c-4fba4a07ef3e
# ╟─373dc480-9a64-4f94-b42d-0145427f95f8
# ╠═d8af8572-a4fe-4553-8801-2bf68c299076
# ╟─e963606c-b88e-4bca-bcbb-7d4e7269aa56
# ╟─1a5d9f8e-4a11-4b68-a53b-2f3e4928680b
# ╠═d1187154-b075-4743-8a4e-570ce37c6f66
# ╠═eb09da2b-cdfb-4fca-8bae-e154a008d974
# ╠═93debb01-597c-4c88-adf4-9394e7664742
# ╠═37012fb7-a9c1-4c42-a732-41b00bae0eaf
# ╠═36e56fba-a298-4e1f-bfc6-9699ea77f8e0
# ╠═10d51d37-62c6-43b5-9a82-21e591b60e9f
# ╠═412eda17-2710-4728-b38b-fb86a8a43c48
# ╠═c2c7bcb5-1a43-4608-9eef-2fe235536b5d
# ╟─e8feb188-8f86-429d-a301-5a8097aa4121
# ╠═41bf4d45-04ca-453e-829b-08a4d699f0c8
# ╠═5f794d76-2530-4c60-a670-894e86fc0ed8
# ╠═90365b61-b2d7-4a4f-b529-f3cdac94a795
# ╠═99d400ec-0b81-4a26-b21b-c45f1671e40f
# ╠═2761a1c6-e56f-4676-a7ea-f66054a5c7f7
# ╠═d981fd7d-1455-47c8-9f82-325f70f9dcc7
# ╟─debe5314-fd82-4af3-b1f7-73772025016b
# ╠═56169522-8fab-454b-a167-551e03d91228
# ╠═89a20ba2-2867-439e-a1cb-f9d4ec74fe05
# ╠═71b25a7b-1c7f-4772-82d9-168520fb917d
# ╠═41fef68a-63ff-47d5-b909-f279dc65bb10
# ╠═be3adadd-828c-4a6f-bd01-272a3d1b3599
# ╠═0f6327b8-4b0e-4cb9-bfce-e6dc419c53a5
# ╠═e3c9f0cb-7f1b-45e1-90c9-103830b81aab
# ╠═572167ef-2fa0-4354-843d-0d9e92c42f00
# ╟─61d8b3f0-d67d-4278-b19e-3e33686e8c45
# ╠═33cc2c7e-b6b5-4ca0-94c3-8f89f3312af4
# ╟─49e94ada-2149-4af0-9b32-fbfaa75a74a3
# ╟─a72a54fe-18d2-44b4-8f77-1d1f0ea8dcb1
# ╟─60563a9e-628b-4fe4-bedd-2573a33e9f77
# ╠═8776f24a-80b2-4611-8480-2b0e50b7cec8
# ╟─772b05e0-7063-4d31-add5-b1f1905df558
# ╠═a7c04406-82b0-488d-9b4e-ada252579ab5
# ╠═615a9812-f192-443d-9bd1-c2b7a625e7ed
# ╠═1e38093f-717f-474f-8e3c-cf2bac18099c
# ╠═b4882722-099e-43d5-86b7-39da98f1c12f
# ╠═79d9b448-1220-48da-b314-53c005869351
# ╠═e687ca73-1546-4c1b-b0ff-04ed86fc299d
# ╠═e9d33e31-aace-47f3-bda6-7e422f4a507d
# ╟─4a893d28-4023-4c51-a1b9-47c812097da7
# ╟─603cc8ce-2702-46ad-95c3-2931c646958f
# ╠═89ba95b9-6c06-4732-9b38-94448595d51d
# ╠═5af7c99f-906d-4642-b060-a53856bdb5cb
# ╠═68a5bf30-ca28-4ca3-ba60-6b031124f0fa
# ╠═d2d7fb19-f3c6-4c82-b662-a32b5d9fe11d
# ╟─960e9ddf-9ca6-4bdf-8356-23bb05217b23
# ╠═a716593f-9050-47ce-a8c7-93c82b5e6dd4
# ╠═f270e723-ead0-4d04-8455-5cd2bf17b9c3
# ╠═29d2d8f7-3b4f-4817-9cb6-95186a4da0da
# ╠═0362c20f-fa97-42eb-b0af-1e2332ee42c5
# ╟─cdeabb5f-9c87-4346-ab38-c86f408189bc
# ╠═5e013596-c983-4486-8853-7607031be4a3
# ╟─8008b883-3adc-480f-8aff-620382e49603
# ╠═f1465ba4-4ca8-4d41-a678-cf9f593a6b57
# ╠═84ddff11-ae06-4bcb-82ab-06e54cbf241d
# ╠═18014b47-f08b-4aed-abb8-d0a7b71f9614
# ╟─511170ac-e9fa-4136-b5f8-6c08126ad297
# ╠═f03504e3-9862-4a2e-8525-9b2df88dfcd3
# ╠═8554d36c-5975-42cb-b8cb-56741097d071
# ╟─66e99f7f-3d1b-4fdc-ac24-4d30c535d654
# ╟─2191cb16-01a7-4f7f-9019-413dc5d52cdc
# ╠═1fe0ba5e-84da-4b57-8aa6-0d946b1b78ee
# ╠═6ac98964-92e0-4cf3-a004-51194f17ee73
# ╠═86ad4a83-44c1-4ce6-a820-e858d9ef5724
# ╠═75801208-efa8-4a3e-b70b-4945727c0c48
# ╠═998fcd81-b3b7-41a5-9130-9614962c4dae
# ╟─753f9f6b-7244-418c-9df7-3c33a7194270
# ╟─c1e49703-7873-4955-8bc5-35cda63c2166
# ╟─2758a0f4-56be-428d-8997-b4c35ff73e25
# ╟─b25eb87f-09bb-44af-81c5-9f2e5905e59f
# ╠═ef5d2e2c-4677-443d-8f96-a7cbea0795be
# ╠═897fd073-5eea-4f2c-850d-7073a7ed0b2e
# ╠═04667800-3b83-4994-9cd4-74e42b724373
# ╟─57f662e0-cbcb-4042-b2c7-36db10246610
# ╟─63ca201c-3de7-490b-a243-20bfbaaea5ed
# ╠═1d8e5cb3-60f2-4292-89c1-550c45c48a3c
# ╠═f4d4135a-c22a-4571-b5bc-bb4c5d0ff03d
# ╠═78e97c71-62c2-49fb-a318-12e760eb1e4c
# ╠═1954d1af-732c-4da5-b43b-1105f35dc814
# ╠═00f33b38-5ad5-4c37-8a22-0501298ff7ae
# ╠═badf936c-98d2-4e72-a138-260e081fb190
# ╠═fd599b11-dda7-4691-aa94-493b68933685
# ╟─53918244-e558-49ac-9456-ed7f0d7782a1
# ╠═a029a74d-2da9-4d62-8a60-c7cef563d664
# ╠═8daf55c2-2d80-426b-9b1e-872daf9e61d4
# ╠═88d67866-9672-496f-90ec-269e5f7ace26
# ╠═5fda9ff0-ccf3-470a-9770-c4054bffefb0
# ╠═5cded9ce-5bcd-4e4d-bc01-d6856d32024d
# ╠═a8319bc2-5175-438a-aa03-2a95b4be3ed6
# ╠═1d818865-534c-4610-9e08-81cf13ef8183
# ╠═871968d6-22bd-45ba-8340-eab8deda0696
# ╠═04338b9f-a5c5-476e-aa6a-450c346b22f4
# ╠═39437ee5-3aa7-453a-b45b-6a2a440d4c1f
# ╠═2efbc23c-bef9-4dd6-89f3-7aaec7167139
# ╠═cf956f77-9292-4c91-940a-21a502c46dc3
# ╠═d4a5ecef-601b-4e37-a2cf-b70d0a056f9e
# ╠═0fb815c6-e782-45fd-bd02-1e893d39dd63
# ╠═e733f2c6-05b7-46b9-95d6-0b482ad7d27b
# ╟─f3310fac-ed65-4e75-8819-ad5f10a5f0c0
# ╠═8b456277-1c55-4b2e-b3d8-222e9e03f954
# ╠═48354c69-37d6-416a-997e-ae59b7ef74d4
# ╠═d022da78-87d3-4dfe-beb6-19a7c37395b3
# ╠═f6dceb5c-2c40-472b-a390-a4c66a56d70c
# ╠═9e2183ec-f5a4-4365-b242-0edba3f30398
# ╠═5f10d16f-af26-40f8-b4f6-3c1a219e47e0
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
