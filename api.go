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
var lastOffboardRequest map[string]string

func main() {
	r := gin.Default()

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
		
		lastOffboardRequest = map[string]string{
			"Voornaam": voornaam,
			"Achternaam": achternaam,
		}
		
		c.JSON(http.StatusOK, gin.H{"message": "Offboarding gestart"})
	})

	r.GET("/offboard", func(c *gin.Context) {
		if lastOffboardRequest != nil {
			c.JSON(http.StatusOK, gin.H{"data": lastOffboardRequest})
			lastOffboardRequest = nil
		} else {
			c.JSON(http.StatusOK, gin.H{"data": map[string]string{}})
		}
	})

	r.Run(":8085")
}
