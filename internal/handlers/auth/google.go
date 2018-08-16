package auth

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"

	jwt "github.com/dgrijalva/jwt-go"
	"github.com/endiangroup/url-shortener/internal/util"
	"github.com/pkg/errors"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

type googleAdapter struct {
	config       *oauth2.Config
	customParams url.Values
}

type googleIdToken struct {
	checkClientID     string
	checkHostedDomain string

	jwt.StandardClaims
	HostedDomain string `json:"hd,omitempty"`
}

func (g *googleIdToken) Valid() error {
	if err := g.StandardClaims.Valid(); err != nil {
		return err
	}

	if !g.StandardClaims.VerifyIssuer("https://accounts.google.com", true) &&
		!g.StandardClaims.VerifyIssuer("accounts.google.com", true) {
		return fmt.Errorf("incorrect issuer")
	}

	if !g.StandardClaims.VerifyAudience(g.checkClientID, true) {
		return fmt.Errorf("incorrect audience")
	}

	if g.checkHostedDomain != "" {
		if subtle.ConstantTimeCompare([]byte(g.HostedDomain), []byte(g.checkHostedDomain)) == 0 {
			return fmt.Errorf("hosted domains don't match")
		}
	}

	return nil
}

// NewGoogleAdapter creates an oAuth adapter out of the credentials and the baseURL
func NewGoogleAdapter(clientID, clientSecret, customParams string) Adapter {
	// TODO: Catch error
	paramValues, _ := url.ParseQuery(customParams)

	return &googleAdapter{
		customParams: paramValues,
		config: &oauth2.Config{
			ClientID:     clientID,
			ClientSecret: clientSecret,
			RedirectURL:  util.GetConfig().BaseURL + "/api/v1/auth/google/callback",
			Scopes: []string{
				"https://www.googleapis.com/auth/userinfo.email",
			},
			Endpoint: google.Endpoint,
		}}
}

func (a *googleAdapter) GetRedirectURL(state string) string {
	var authCodeOptions []oauth2.AuthCodeOption
	if len(a.customParams) != 0 {
		for key, val := range a.customParams {
			authCodeOptions = append(authCodeOptions, oauth2.SetAuthURLParam(key, strings.Join(val, ",")))
		}
	}

	return a.config.AuthCodeURL(state, authCodeOptions...)
}

func (a *googleAdapter) GetUserData(state, code string) (*user, error) {
	oAuthToken, err := a.config.Exchange(context.Background(), code)
	if err != nil {
		return nil, errors.Wrap(err, "could not exchange code")
	}

	hostedDomain := a.customParams.Get("hd")
	if hostedDomain != "" {

		idTokenRaw := oAuthToken.Extra("id_token").(string)
		if idTokenRaw == "" {
			return nil, errors.New("no id token found")
		}

		// TODO: Verify ID Token signature, requires JWK fudgery
		claims := &googleIdToken{
			checkClientID:     a.config.ClientID,
			checkHostedDomain: hostedDomain,
		}
		parser := jwt.Parser{}
		_, _, err = parser.ParseUnverified(idTokenRaw, claims)
		if err != nil {
			return nil, err
		}

		if err = claims.Valid(); err != nil {
			return nil, err
		}
	}

	oAuthUserInfoReq, err := a.config.Client(context.Background(), oAuthToken).Get("https://www.googleapis.com/oauth2/v3/userinfo")
	if err != nil {
		return nil, errors.Wrap(err, "could not get user data")
	}
	defer oAuthUserInfoReq.Body.Close()
	var gUser struct {
		Sub     string `json:"sub"`
		Name    string `json:"name"`
		Picture string `json:"picture"`
	}
	if err = json.NewDecoder(oAuthUserInfoReq.Body).Decode(&gUser); err != nil {
		return nil, errors.Wrap(err, "decoding user info failed")
	}
	return &user{
		ID:      gUser.Sub,
		Name:    gUser.Name,
		Picture: gUser.Picture + "?sz=64",
	}, nil
}

func (a *googleAdapter) GetOAuthProviderName() string {
	return "google"
}
