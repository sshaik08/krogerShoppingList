#!/bin/bash

# === CONFIGURATION ===

CLIENT_ID=[client_id]
CLIENT_SECRET=[client_secret]
ZIP_CODE="45044"
RESULT_LIMIT=5

# =====================

echo "getting access token..."

TOKEN=$(curl -s --compressed -X POST \
"https://api-ce.kroger.com/v1/connect/oauth2/token" \
-H "Accept: application/json" \
-H "Content-Type: application/x-www-form-urlencoded" \
-H "Authorization: Basic $(printf '%s' "$CLIENT_ID:$CLIENT_SECRET" | base64)" \
-d "grant_type=client_credentials&scope=product.compact" \
| jq -r '.access_token')

if [ "$TOKEN" == "null" ]; then
  echo "Failed to retrieve access token"
  exit 1
fi


echo "getting nearest location..."

LOCATION_ID=$(curl -s \
"https://api-ce.kroger.com/v1/locations?filter.zipCode.near=$ZIP_CODE&filter.limit=1" \
-H "Authorization: Bearer $TOKEN" \
| jq -r '.data[0].locationId')

echo "using location id $LOCATION_ID"

if [ "$LOCATION_ID" == "null" ]; then
  echo "Failed to get location"
  exit 1
fi

while IFS= read -r ITEM
do
	echo ""
	echo "results for $ITEM"
	
	ENCODED_ITEM=$(printf '%s' "$ITEM" | jq -sRr @uri)

	curl -s \
	"https://api-ce.kroger.com/v1/products?filter.term=$ENCODED_ITEM&filter.locationId=$LOCATION_ID&filter.limit=$RESULT_LIMIT" \
	-H "Authorization: Bearer $TOKEN" \
	| jq '
		.data[]? 
		| select(
			(.items[0].price.regular != null) and
			(.items[0].inventory.stockLevel != "TEMPORARILY_OUT_OF_STOCK") and
			(.items[0].inventory.stockLevel != null)
			)
		| {
		productId,
		brand,
		description,
		price: (
			.items[0].price.regular
			// .items[0].price.promo
			// "not available"
			)
		}
	'

done < shoppingList.txt