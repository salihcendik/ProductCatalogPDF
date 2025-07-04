public with sharing class ProductCatalogPDF_CASController {
    private static final Integer COVER_PAGE_COUNT = 1;
    private static final Integer MAX_TITLE_ROW_IN_CONTENT_PAGE = 20;
    public String currencySymbol { get; set; }
    public String catalogCurrencyCode { get; set; }
    public String brandName { get; set; }
    public String brandLogo { get; set; }
    public String catalogVersion { get; set; }
    public String coverImage { get; set; }
    public Sales_Organization__mdt socialInfo { get; set; }
    public String salesOrg { get; set; }
    public String distChannel { get; set; }
    public List<SerialCollection> selectedSerials { get; set; }
    public Map<String, SerialCollection> serialCollectionMap { get; set; }
    public List<Integer> dynamicColumnIndexes { get{ return new List<Integer>{1, 2, 3, 4, 5, 6}; } set;}
    public static final List<String> PRODUCT_FIELDS = new List<String>{
        'Product_1__c', 'Product_2__c', 'Product_3__c',
        'Product_4__c', 'Product_5__c', 'Product_6__c'
    };

    // Transient properties
    transient public List<Product_Catalog__c> productCatalogs { get; set; }
    transient public List<String> titles { get; set; }
    transient public List<String> subTitles { get; set; }
    transient public List<Integer> pageNumbers { get; set; }
    transient public Map<String, String> serialTablePriceMap { get; set; }

    public ProductCatalogPDF_CASController() {
        processCatalogData();
    }

    private void processCatalogData() {
        fetchCatalogData();
        buildSerialCollectionMap();
        loadProductCatalogs();
        calculatePageDetails();
        getBrandDetails();
        calculateProductPrices();
        initializeCurrencyCode();
        fetchSocialInfo();
    }

    private void fetchCatalogData() {
        Id logId = ApexPages.currentPage().getParameters().get('Id');
        ProductCatalogPDFLog__c catalogData = [
            SELECT Series_Collection_JSON__c, Sales_Org__c, Distribution_Channel__c, PDF_Name__c 
            FROM ProductCatalogPDFLog__c 
            WHERE Id = :logId
            LIMIT 1
        ];

        salesOrg = catalogData.Sales_Org__c;
        distChannel = catalogData.Distribution_Channel__c;
        selectedSerials = (List<SerialCollection>) JSON.deserialize(catalogData.Series_Collection_JSON__c, List<SerialCollection>.class);
        Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename=' + catalogData.PDF_Name__c + '.pdf');
    }

    private void buildSerialCollectionMap() {
        serialCollectionMap = new Map<String, SerialCollection>();
        for (SerialCollection sc : selectedSerials) {
            serialCollectionMap.put(sc.Name, sc);
        }
    }

    public void getBrandDetails(){
        Product_Catalog__c firstCatalog = productCatalogs[0];
        brandName = firstCatalog.RootExternalKey__r.Brand_Name__c;
        brandLogo = firstCatalog.RootExternalKey__r.Brand_Image__c;
        catalogCurrencyCode = firstCatalog.RootExternalKey__r.Target_Currency__c;
        catalogVersion = firstCatalog.RootExternalKey__r.Version__c;
        coverImage = firstCatalog.RootExternalKey__r.Catalog_Cover_Image_Path__c;
    }

    private void loadProductCatalogs() {
        productCatalogs = [
            SELECT 
                Name, Serial_Header__c, Serial_Sub_Header__c, Serial_Sub_Text__c, Serial_Image_Path__c, 
                FiltersAndElementsSubNote__c, GeneralWorkingConditionsSubNote__c, CorrectionFactorsSubNote__c, AccessoriesSubNote__c, 
                RootExternalKey__r.Target_Currency__c, RootExternalKey__r.Catalog_Cover_Image_Path__c, RootExternalKey__r.Brand_Image__c,
                RootExternalKey__r.Brand_Name__c, RootExternalKey__r.Version__c,
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Price_Line__c, Product_1__c, Product_2__c, Product_3__c, Product_4__c, Product_5__c, Product_6__c
                    FROM ModelAndSpecifications__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c, Price_Line__c
                    FROM ShippingDimensionsAndWeights__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Price_Line__c, Product_1__c, Product_2__c, Product_3__c, Product_4__c, Product_5__c, Product_6__c
                    FROM FiltersAndElements__r  
                    ORDER BY ID__c
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c, Price_Line__c
                    FROM GeneralWorkingConditions__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c, Column_7__c,
                    Column_8__c, Column_9__c, Column_10__c, Column_11__c, Column_12__c, Column_13__c, Column_14__c, Column_15__c, Price_Line__c
                    FROM CorrectionFactors__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Price_Line__c, Product_1__c, Product_2__c, Product_3__c, Product_4__c, Product_5__c, Product_6__c
                    FROM OptionCollections__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Price_Line__c, Product_1__c, Product_2__c, Product_3__c, Product_4__c, Product_5__c, Product_6__c
                    FROM AccessoryCollections__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Column_7__c, Column_8__c, Column_9__c, Price_Line__c
                    FROM NitrogenCompressedAirCollections__r  
                    ORDER BY ID__c  
                ),
                (  
                    SELECT Content__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Column_5__c, Column_6__c,
                        Column_7__c, Column_8__c, Column_9__c, Price_Line__c
                    FROM NitrogenCompressedRequireds__r  
                    ORDER BY ID__c  
                )
            FROM Product_Catalog__c 
            WHERE Name IN :serialCollectionMap.keySet()     
            ORDER BY Serial_ID__c
        ];
    }

    private void initializeCurrencyCode() {
        currencySymbol = fetchCurrencySymbol(catalogCurrencyCode);
    }

    private String fetchCurrencySymbol(String currencyCode) {
		switch on currencyCode {
			when 'USD' {		
				return '$';
			}when 'EUR' {		
				return '€';
			}when 'TL' {		
				return '₺';
			}when else {	
				return '';			
			}
		}
    }

    private void calculatePageDetails() {
        Set<String> uniqueTitles = new Set<String>();
        for (Product_Catalog__c pc : productCatalogs) {
            uniqueTitles.add(pc.Serial_Header__c);
        }

        Integer contentPageCount = (uniqueTitles.size() + MAX_TITLE_ROW_IN_CONTENT_PAGE - 1) / MAX_TITLE_ROW_IN_CONTENT_PAGE;
        Integer currentPageNumber = COVER_PAGE_COUNT + contentPageCount + 1;

        titles = new List<String>();
        subTitles = new List<String>();
        pageNumbers = new List<Integer>();
        
        for (Product_Catalog__c pc : productCatalogs) {
            if (!titles.contains(pc.Serial_Header__c)) {
                titles.add(pc.Serial_Header__c);
                subTitles.add(pc.Serial_Sub_Header__c ?? ' ');
                pageNumbers.add(currentPageNumber);
            }
            currentPageNumber++;
        }
    }

    private void calculateProductPrices() {
        Set<Id> productIds = extractProductIdsFromSeriesTables();
        if (productIds.isEmpty()) return;

        Map<Id, Product2> productPriceMap = fetchProductsWithPrices(productIds);
        serialTablePriceMap = buildSerialTablePriceMap(productPriceMap);
    }

    private Set<Id> extractProductIdsFromSeriesTables() {
        Set<Id> productIds = new Set<Id>();
        serialTablePriceMap = new Map<String, String>();

        for (Product_Catalog__c catalog : productCatalogs) {
            collectProductIds(productIds, catalog);
        }
        return productIds;
    }

    private void collectProductIds(Set<Id> productIds, Product_Catalog__c catalog) {
        List<List<sObject>> allSubCatalogs = new List<List<sObject>>{
            catalog.ModelAndSpecifications__r,
            catalog.FiltersAndElements__r,
            catalog.OptionCollections__r,
            catalog.AccessoryCollections__r
        };

        for (List<sObject> subCatalogs : allSubCatalogs) {
            for (sObject sub : subCatalogs) {
                String priceLine = (String) sub.get('Price_Line__c');
                if (priceLine != 'True') continue;
                String subId = (String) sub.get('Id');
                for (Integer i = 1; i <= 6; i++) {
                    String productId = (String) sub.get('Product_' + i + '__c');
                    serialTablePriceMap.put(subId + '_' + (productId ?? ''), '');
                    if (productId != null) {
                        productIds.add(productId);
                    }
                }
            }
        }
    }

    private Map<Id, Product2> fetchProductsWithPrices(Set<Id> productIds) {
        return new Map<Id, Product2>([
            SELECT Id,
                (SELECT Value__c
                FROM Price_Lists__r
                WHERE Condition_Type__c = 'ZP03'
                AND Deleted__c = false
                AND Valid_From__c <= TODAY
                AND Valid_To__c >= TODAY
                AND Sales_Organization__c = :salesOrg
                AND Distribution_Channel__c = :distChannel
                AND CurrencyIsoCode = :catalogCurrencyCode
                LIMIT 1)
            FROM Product2
            WHERE Id IN :productIds
        ]);
    }

    private Map<String, String> buildSerialTablePriceMap(Map<Id, Product2> productPriceMap) {
        for (Product_Catalog__c catalog : productCatalogs) {
            Decimal discount = serialCollectionMap.get(catalog.Name)?.Discount ?? 0;

            List<List<sObject>> subCatalogGroups = new List<List<sObject>>{
                catalog.ModelAndSpecifications__r,
                catalog.FiltersAndElements__r,
                catalog.OptionCollections__r,
                catalog.AccessoryCollections__r
            };

            for (List<sObject> subCatalogs : subCatalogGroups) {
                assignPrices(subCatalogs, productPriceMap, discount);
            }
        }
        return serialTablePriceMap;
    }

    private void assignPrices(List<sObject> subCatalogs, Map<Id, Product2> productPriceMap, Decimal discount) {
        for (sObject sub : subCatalogs) {
            String priceLine = (String) sub.get('Price_Line__c');
            if (priceLine != 'True') continue;
            String subId = (String) sub.get('Id');
            for (String fieldName : PRODUCT_FIELDS) {
                String productId = (String) sub.get(fieldName);
                String formattedPrice = calculateDiscountedFormattedPrice(productId, productPriceMap, discount);
                if (formattedPrice != null) {
                    serialTablePriceMap.put(subId + '_' + (productId ?? ''), formattedPrice);
                }
            }
        }
    }

    private String calculateDiscountedFormattedPrice(Id productId, Map<Id, Product2> productPriceMap, Decimal discount) {
        if (!productPriceMap.containsKey(productId)) return null;

        Product2 product = productPriceMap.get(productId);
        if (product.Price_Lists__r.isEmpty()) return null;

        Decimal basePrice = product.Price_Lists__r[0].Value__c;
        Decimal netPrice = (basePrice * (1 - discount / 100)).setScale(2);
        return formatPrice(netPrice);
    }

    private String formatPrice(Decimal price) {
        String priceStr = String.valueOf(price);
        return (catalogCurrencyCode != 'USD') ? priceStr.replace('.', ',') : priceStr;
    }

    private void addProductId(Set<Id> productIds, List<sObject> subCatalogs) {
        for (sObject subCatalog : subCatalogs) {
            for (String fieldName : PRODUCT_FIELDS) {
                serialTablePriceMap.put((Id) subCatalog.get('Id'), '');
                Id productId = (Id) subCatalog.get(fieldName);
                if (productId != null) {
                    productIds.add(productId); 
                }
            }
        }
    }

    private void fetchSocialInfo() {
        socialInfo = Sales_Organization__mdt.getInstance('S_'+salesOrg);
    }

    public class SerialCollection {
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public Decimal Discount { get; set; }
    }
}