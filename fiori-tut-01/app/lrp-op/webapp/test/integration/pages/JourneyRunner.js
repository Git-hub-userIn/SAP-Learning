sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"sap/practice/lrpop/test/integration/pages/ProductsList",
	"sap/practice/lrpop/test/integration/pages/ProductsObjectPage",
	"sap/practice/lrpop/test/integration/pages/SuppliersObjectPage"
], function (JourneyRunner, ProductsList, ProductsObjectPage, SuppliersObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('sap/practice/lrpop') + '/test/flp.html#app-preview',
        pages: {
			onTheProductsList: ProductsList,
			onTheProductsObjectPage: ProductsObjectPage,
			onTheSuppliersObjectPage: SuppliersObjectPage
        },
        async: true
    });

    return runner;
});

