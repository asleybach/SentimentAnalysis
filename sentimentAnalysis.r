#----------------------------------INSTALAR LIBRERIAS----------------------------------#
#Correr unicamente la primera vez
# install.packages("ROAuth")
# install.packages("twitteR")
# install.packages("base64enc")
# install.packages("httr")
# install.packages("devtools")
# install.packages("tm")
# install.packages("wordcloud")
# install.packages("RColorBrewer")
# install.packages("RTextTools")
# ggplot no disponible para la versi�n 3.4.3 de R

#-----------------------------------CARGAR LIBRERIAS-----------------------------------#
library(ROAuth)
library(twitteR)
library(base64enc)
library(httr)
library(devtools)
library(tm)
library(wordcloud)
library(RColorBrewer)
library(RTextTools)

#Sentiment Palabras
# https://cran.r-project.org/src/contrib/Archive/sentiment/
# http://cran.r-project.org/src/contrib/Archive/sentiment/sentiment_0.2.tar.gz

# interface to the C code that implements Porter's word stemming algorithm for collapsing words to a common root to aid comparison of texts. There 
# install_url('http://cran.r-project.org/src/contrib/Archive/Rstem/Rstem_0.4-1.tar.gz')

#-------------------------------AUTENTICACI�N DE TWITTER-------------------------------#
#Realizar autenticaci�n con Twitter
api_key = "Y5fbQA5lJodmk0E4q4c1DYbXD"
api_secret = "f4OQTcDmCg56EiHEaSZ7Zo3POHrEn2T0QHj0KbqBmZyRWmNkVL"
access_token = "919998032938012672-6GP05oGCs1SZ6cwP9QwXw8VWulKDXDe"
access_token_secret = "YWOmWI4B3UTzOeYMVyipwVtiQvzIqygfO2cN2ySd1RZk4"
request_url = 'https://api.twitter.com/oauth/request_token'
access_url = 'https://api.twitter.com/oauth/access_token'
auth_url = 'https://api.twitter.com/oauth/authorize'

#Realizar autenticaci�n de la app
setup_twitter_oauth(api_key, api_secret, access_token, access_token_secret)

#Obtener credencial
credential = OAuthFactory$new(consumerKey = api_key,
                              consumerSecret = api_secret,
                              requestURL = request_url,
                              accessURL = access_url,
                              authURL = auth_url)

#Autorizar credencial de la app
credential$handshake(cainfo = system.file("CurlSSL", "cacert.pem", package ="RCurl")) 

#--------------------------------EXTRACCI�N DE TWEETS--------------------------------#
#Buscar y extraer tweets
iphoneTweets = searchTwitter("iPhone X", n=5000, lang="en", since = "2017-06-01")
noteTweets = searchTwitter("Galaxy Note 8", n=5000, lang="en", since = "2017-06-01")
pixelTweets = searchTwitter("Google+Pixel 2", n=5000, lang="en", since = "2017-06-01")

#Convertir la lista de tweets a dataframe
iphoneTweets.df = twListToDF(iphoneTweets)
noteTweets.df = twListToDF(noteTweets)
pixelTweets.df = twListToDF(pixelTweets)

#Obtener nombres de columnas de los datos
names(iphoneTweets.df)

#Obtener solo la parte textual del dataframe
iphoneTweets.text = iphoneTweets.df$text
noteTweets.text = noteTweets.df$text
pixelTweets.text = pixelTweets.df$text

#---------------------------------LIMPIEZA DE TWEETS---------------------------------#
#Crear funci�n para depurar los tweets
tweets.clean = function(tweetsList){

  cleanedTweets = sapply(tweetsList,function(row) iconv(row, "latin1", "ASCII", sub=""))
    
  #Eliminar cualquier tipo de caracter no manejable por r
  cleanedTweets = gsub("(f|ht)tp(s?)://(.*)[.][a-z]+", "", cleanedTweets)
  
  #Convertir a Corpus (lista de documentos de texto) el vector de caracteres
  tweetsCorpus = Corpus(VectorSource(cleanedTweets[names(cleanedTweets)]))
  
  #Eliminar enlaces que comiencen con "http"
  tweetsCorpus = tm_map(tweetsCorpus, function(tweet) gsub("http[^[:space:]]*", "", tweet))
  #   
  # #Eliminar caracteres
  tweetsCorpus = tm_map(tweetsCorpus, function(tweet) gsub("\xed[^[:space:]]*", "", tweet))
  #   
  # #Eliminar otros enlaces raros que comiencen con "/"
  tweetsCorpus = tm_map(tweetsCorpus, function(tweet) gsub("/[^[:space:]]*", "", tweet))
  #   
  # #Eliminar usuarios (@usuarioX)
  tweetsCorpus = tm_map(tweetsCorpus, function(tweet) gsub("@[^[:space:]]*", "", tweet))
  # 
  # #Elimina signos de puntuaci�n
  tweetsCorpus = tm_map(tweetsCorpus, removePunctuation)
  #   
  # #Transformar todo a min�sculas
  tweetsCorpus = tm_map(tweetsCorpus, content_transformer(tolower))
  #   
  # #Eliminar palabras innecesarias, saltos de l�nea y rt's.
  tweetsCorpus = tm_map(tweetsCorpus, removeWords, c(stopwords("english"),"\n","rt")) 
  #   
  # #Eliminar n�meros
  tweetsCorpus = tm_map(tweetsCorpus, removeNumbers) 
  #   
  # #Eliminar la(s) palabra(s) buscada(s) o fuertemente relacionadas con la b�squeda
  searchedWords = c("iphone x","iphonex","iphone","apple","ios","galaxy","galaxynote",
                       "note","note 8","samsung","android","google","pixel","pixel 2",
                       "pixel2","phone","smartphone","cellphone","giveaway","international","tweet")
     
  tweetsCorpus = tm_map(tweetsCorpus, removeWords, searchedWords) 
  #  
  # #Eliminar espacios en blanco extras
  tweetsCorpus = tm_map(tweetsCorpus, stripWhitespace)
  
  cleanedTweets = data.frame(text = sapply(tweetsCorpus, as.character), stringsAsFactors = FALSE)
  #cleanedTweets = list(text = sapply(tweetsCorpus, as.character))
  return(cleanedTweets)
}
iphoneCleanedTweets = tweets.clean(iphoneTweets.text)
noteCleanedTweets = tweets.clean(noteTweets.text)
pixelCleanedTweets = tweets.clean(pixelTweets.text)

#----------------------ADJUNTAR CONJUNTO DE DATOS DE PALABRAS----------------------#
#Almacenar en posWords la lista de palabras positivas ignorando la secci�n comentada
posWords = scan('./posWords.txt', what='character', comment.char = ';')

#Almacenar en negWords la lista de palabras negativas ignorando la secci�n comentada
negWords = scan('./negWords.txt', what='character', comment.char = ';')

#------------FUNCIONES DE PUNTUACION POR PALABRAS POSITIVAS Y NEGATIVAS------------#
#Crear funci�n para obtener puntuaciones
getScores = function(tweets, pos.words, neg.words){
  results.df = data.frame(matrix(nrow=0,ncol=5))
  
  for(i in 1:length(tweets)){
    tweet = tweets[i]
    words = strsplit(tweet,' ')
    words = unlist(words)
    words = words[!words %in% c(""," ","NA")]
    
    pos.match  = match(words, posWords)
    pos.match = !is.na(pos.match)
    neg.match = match(words,negWords)
    neg.match = !is.na(neg.match)
    totalPos = sum(pos.match)
    totalNeg = sum(neg.match)
    score = totalPos - totalNeg
    
    #Score = {{-5,-4,-3},{-2,-1},{0},{1,2},{3,4,5}}
    
    if(score <= -3){
      category = "very negative"
    }
    else if(score < 0 && score > 3){
      category = "negative"
    }
    else if(score == 0){
      category = "neutral"
    }
    else if(score > 0 && score <= 2){
      category = "positive"
    }
    else{
      category = "very positive"
    }
    if(length(words) != 0L){
      results.df[i,]= c(tweet,totalPos,totalNeg,score,category)
    }
  }
  
  colnames(results.df) = c("tweet","pos","neg","score","category")
  return(results.df)
}

#Almacenar puntuaciones en variables de los dispositivos
iphone.scores = getScores(iphoneCleanedTweets$text, posWords, negWords)
note.scores = getScores(noteCleanedTweets$text, posWords, negWords)
pixel.scores = getScores(pixelCleanedTweets$text, posWords, negWords)

#------------------------FUNCIONES DE POLARIDAD Y EMOCIONES------------------------#

#Funcion para crear la matriz necesaria en bayesianEmotions() y en bayesianPolarity()
createMatrix = function(textColumns,language="english", minDocFreq=1, minWordLength=3,weighting=weightTf){
  #Se crea el control para el Corpus
  control = list(language=language,minDocFreq=minDocFreq,minWordLength=minWordLength,weighting=weighting)
  
  #Se genera una columna en forma de matriz con los tweets
  trainingColumn = apply(as.matrix(textColumns),1,paste,collapse=" ")
  
  #Se convierte la matriz a un vector
  trainingColumn = sapply(as.vector(trainingColumn,mode="character"),iconv,to="UTF8",sub="byte")
  
  #Se convierte el vector a un corpus
  corpus = Corpus(VectorSource(trainingColumn),readerControl=list(language=language))
  
  #Se genera la matriz 
  matrix = DocumentTermMatrix(corpus,control=control)
  
  return(matrix)
}

#Funcion para obtener las emociones correspondientes a cada tweet
bayesianEmotions = function(tweets,prior=1.0){
  matrix = createMatrix(tweets)
  
  #Leer el documento de emociones
  lexicon = read.csv(file = "emotions.csv",header=FALSE,sep=",")
  
  #Se obtiene una lista con la cantidad de palabras correspondientes a las emociones
  counts = list(anger=length(which(lexicon[,2]=="anger")),disgust=length(which(lexicon[,2]=="disgust")),fear=length(which(lexicon[,2]=="fear")),joy=length(which(lexicon[,2]=="joy")),sadness=length(which(lexicon[,2]=="sadness")),surprise=length(which(lexicon[,2]=="surprise")),total=nrow(lexicon))
  
  #Se crea un vector vacio
  documents = c()
  
  #Se realiza una iteracion por tweet
  for(i in 1:nrow(matrix)){
    scores = list(anger=0,disgust=0,fear=0,joy=0,sadness=0,surprise=0)
    doc = matrix[i,]
    words = findFreqTerms(doc,lowfreq=1)
    
    #Se obtienen las palabras del tweet iterado
    for(word in words){
      for(key in names(scores)){
        emotions = lexicon[which(lexicon[,2]==key),]
        index = pmatch(word,emotions[,1],nomatch=0)
        if(index>0){
          entry = emotions[index,]
          category = as.character(entry[[2]])
          count = counts[[category]]
          score = 1.0
          score = abs(log(score*prior/count))
          
          #Se asigna su puntuaci�n en la categor�a de emociones correspondiente
          scores[[category]] = scores[[category]]+score
        }
      }
    }
    
    #Se itera sobre las columnas de "scores"
    for(key in names(scores)){
      count = counts[[key]]
      total = counts[["total"]]
      score = abs(log(count/total))
      
      #Se asigna la puntuacion del tweet 
      scores[[key]]  = scores[[key]]+score
    }
    
    best_fit = names(scores)[which.max(unlist(scores))]
    
    #Si el radio es menor a .01 se considera como no clasificable
    if(best_fit == "disgust" && as.numeric(unlist(scores[2]))-3.09234 < .01){
      best_fit = NA
    }
    
    #Se anexan las puntuaciones y la clasificaci�n al vector vacio 
    documents = rbind(documents,c(scores$anger,scores$disgust,scores$fear,scores$joy,scores$sadness,scores$surprise,best_fit))
  }
  
  #Se nombran las columnas del vector documents
  colnames(documents) = c("Anger","Disgust","Fear","Joy","Sadness","Surprise","Emotion")
  return(documents)
}

#Funcion para obtener la polaridad de la lista de tweets
bayesianPolarity = function(tweets,pStrong=0.5,pWeak=1.0,prior=1.0){
  matrix = createMatrix(tweets)
  #Leer el documento de subjetividad de palabras
  lexicon = read.csv(file = "subjectivity.csv",header=FALSE,sep=",")
  
  #Se obtiene una lista con la cantidad de palabras positivas, negativas, y la suma de dichas palabras
  counts = list(positive=length(which(lexicon[,3]=="positive")),negative=length(which(lexicon[,3]=="negative")),total=nrow(lexicon))
  
  #Se crea un vector vacio
  documents = c()
  
  #Se realiza una iteraci�n por tweet
  for(i in 1:nrow(matrix)){
    scores = list(positive=0,negative=0)
    doc = matrix[i,]
    words = findFreqTerms(doc,lowfreq=1)
    
    #Se obtienen las palabras del tweet iterado
    for(word in words){
      index = pmatch(word,lexicon[,1],nomatch=0)
      if(index>0){
        entry = lexicon[index,]
        polarity = as.character(entry[[2]])
        category = as.character(entry[[3]])
        count = counts[[category]]
        score = pWeak
        score = abs(log(score*prior/count))
      
        #Se asigna su puntuaci�n en la categor�a (positivo o negativo) correspondiente
        scores[[category]] = scores[[category]]+score
      }
    }
    
    #Se itera sobre las columnas de "scores"
    for(key in names(scores)){
      count = counts[[key]]
      total = counts[["total"]]
      score = abs(log(count/total))
      
      #Se asigna la puntuacion del tweet (polar)
      scores[[key]] = scores[[key]]+score
    }
    
    best_fit = names(scores)[which.max(unlist(scores))]
    ratio = as.integer(abs(scores$positive/scores$negative))
    
    #Si el radio es igual a 1, se asigna al grupo de "neutral"
    if(!length(ratio)==0){
      if(ratio==1){
        best_fit="neutral"
      }
    }
    
    #Se anexan las puntuaciones y la clasificaci�n al vector vacio
    documents = rbind(documents,c(scores$positive,scores$negative,abs(scores$positive/scores$negative),best_fit))
  }
  
  #Se nombran las columnas del vector documents
  colnames(documents) = c("Pos","Neg","Pos/Neg","Polarity")
  return(documents)
}

#Obtener la clasificacion de los tweets por emociones
iphoneEmotions.class = bayesianEmotions(iphone.scores$tweet)
#Se obtiene la lista de las emociones que mejor se ajustan al tweet
iphoneEmotions = iphoneEmotions.class[,7]
#Reemplazar los valores "NA" por desconocido ("unknown")
iphoneEmotions[is.na(iphoneEmotions)] = 'unknown'

#Obtener la clasificaci�n de los tweets por polaridad
iphonePolarity.class = bayesianPolarity(iphone.scores$tweet)
#Se obtiene la lista de la clasificaci�n de polaridad
iphonePolarity = iphonePolarity.class[,4]
#Se crea un dataframe con las estad�sticas de los tweets
iphonePolarity = data.frame(text=iphone.scores$tweet, emotion=iphoneEmotions, polarity=iphonePolarity, stringAsFactors=FALSE)

#-----------------------------GRAFICACION DE RESULTADOS----------------------------#

hist(as.numeric(iphone.scores$score))

################################################################################
################################################################################

#https://github.com/timjurka/sentiment/tree/master/sentiment/R   -> Funciones de sentimiento

#https://rstudio-pubs-static.s3.amazonaws.com/66739_c4422a1761bd4ee0b0bb8821d7780e12.html

###############################################################################
###############################################################################









