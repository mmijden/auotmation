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

type OffboardData struct {
	Voornaam   string `json:"Voornaam" binding:"required"`
	Achternaam string `json:"Achternaam" binding:"required"`
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
		c.JSON(http.StatusOK, gin.H{"message": "Gegevens ontvangen"})
	})

	r.GET("/Staff", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"data": storedData})
	})

	r.POST("/offboard", func(c *gin.Context) {
		var offboardData OffboardData
		if err := c.ShouldBindJSON(&offboardData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Offboarding started"})
	})

	r.Run(":8085")
}
