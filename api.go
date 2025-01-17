package main

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

type FormData struct {
	Personeelsnummer string `form:"Personeelsnummer" binding:"required"`
	Voornaam         string `form:"Voornaam" binding:"required"`
	Achternaam       string `form:"Achternaam" binding:"required"`
	Afdeling         string `form:"Afdeling" binding:"required"`
	Email            string `form:"Email" binding:"required"`
}

var storedData FormData

func main() {
	r := gin.Default()

	// Enable CORS
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	r.POST("/submit", func(c *gin.Context) {
		var formData FormData
		if err := c.ShouldBind(&formData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		storedData = formData
		c.JSON(http.StatusOK, gin.H{"message": "Gegevens ontvangen", "data": formData})
	})

	r.GET("/Staff", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"data": storedData})
	})

	r.POST("/offboard", func(c *gin.Context) {
		voornaam := c.PostForm("Voornaam")
		achternaam := c.PostForm("Achternaam")
		c.JSON(http.StatusOK, gin.H{"message": "Offboarding gestart", "data": gin.H{
			"Voornaam": voornaam,
			"Achternaam": achternaam,
		}})
	})

	r.Run(":8085")
}
