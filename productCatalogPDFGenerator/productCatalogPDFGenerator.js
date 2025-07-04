import { LightningElement, wire } from 'lwc';
//APEX
import getDistricts from '@salesforce/apex/ProductCatalogPDFController.getDistrictByRootCollection';
import getSerialCollections from '@salesforce/apex/ProductCatalogPDFController.getActiveSerialCollectionByRootKey';
//LWC
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import { createRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import LightningConfirm from 'lightning/confirm';
//SCHEMA
import LOG_OBJECT from "@salesforce/schema/ProductCatalogPDFLog__c";
import PDF_NAME_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.PDF_Name__c";
import SALES_ORG_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.Sales_Org__c";
import DIST_CHANNEL_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.Distribution_Channel__c";
import SERIAL_JSON_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.Series_Collection_JSON__c";
import SYSTEM_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.System__c";
import DISTRICT_FIELD from "@salesforce/schema/ProductCatalogPDFLog__c.District__c";

const PDF_URL_HVAC = '/apex/ProductCatalogPDF_HVAC?Id=';
const PDF_URL_CAS = '/apex/ProductCatalogPDF_CAS?Id=';
export default class ProductCatalogPDFGenerator extends NavigationMixin(LightningElement) {
    MAX_DISCOUNT = 50;
    DISCOUNT_ERROR_MESSAGE = `Discount cannot exceed ${this.MAX_DISCOUNT}%`;
    pdfUrlPrefixForCas = '/apex/ProductCatalogPDF_CAS?Id=';
    systemOptions = [
        { label: 'HVAC', value: 'Root_Collection_HVAC' },
        { label: 'CAS', value: 'Root_Collection_CAS' }
    ];
    serialColumns = [
        { label: 'Discount', fieldName: 'Discount', type: 'number', editable: true, initialWidth: 100 },
        { label: 'Name', fieldName: 'Name', initialWidth: 200 },
        { label: 'Serial Header', fieldName: 'Serial_Header__c', initialWidth: 200 },
        { label: 'Serial Sub Header', fieldName: 'Serial_Sub_Header__c' },
        { label: 'Group Id', fieldName: 'Group_Id__c' },
    ];

    discountOptions = [
        { label: '5%', value: '5' },
        { label: '10%', value: '10' },
        { label: '15%', value: '15' },
        { label: '20%', value: '20' },
        { label: '25%', value: '25' },
        { label: '30%', value: '30' },
        { label: '35%', value: '35' },
        { label: '40%', value: '40' },
        { label: '45%', value: '45' },
        { label: '50%', value: '50' }
    ];

    distChannelOptions = [];
    salesOrgOptions = [];
    districtOptions = [];
    serialData = [];
    filteredSerial = [];
    draftSerialValues = [];
    preSelectedSerialRowIds = [];
    errors = {};
    isLoadingSerialTable = false;
    isLoadingPDF = false;
    isLoading = false;
    selectedSystem;
    selectedDistrict;
    selectedDiscount;
    selectedSerialRowCount;
    pdfUrl;
    currentPdfLog;
    pdfModalHeader;
    showPdfModal = false;

    @wire(getPicklistValues, { recordTypeId: "012000000000000AAA", fieldApiName: SALES_ORG_FIELD })
    salesOrgPicklistResults({ error, data }) {
        if (data) {
            this.salesOrgOptions = data.values;
        } else if (error) {
            console.error('Error fetching sales org picklist values:', error);
            this.salesOrgOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "012000000000000AAA", fieldApiName: DIST_CHANNEL_FIELD })
    distChannelPicklistResults({ error, data }) {
        if (data) {
            this.distChannelOptions = data.values;
        } else if (error) {
            console.error('Error fetching dist channel picklist values:', error);
            this.distChannelOptions = [];
        }
    }
    
    handleSystemChange(event) {
        this.selectedSystem = event.detail.value;
        this.resetSerialCollections();
        this.loadDistricts();
    }

    async loadDistricts() {
        try {
            const data = await getDistricts({ rootCollectionName: this.selectedSystem });
            this.districtOptions = this.mapToComboboxOptions(data, 'Id', 'District__c');
        } catch (error) {
            console.log('Error in loadDistricts:', error);
        }
    }

    handleDistrictChange(event) {
        this.selectedDistrict = event.detail.value;
        this.loadSerialCollections();
    }

    async loadSerialCollections() {
        try {
            this.isLoadingSerialTable = true;
            this.serialData = (await getSerialCollections({ rootKey: this.selectedDistrict }))
                .map(item => ({
                    ...item,
                    IsSelected: true,
                    Discount: this.selectedDiscount
                }));
            this.filteredSerial = [...this.serialData];
            this.preSelectedSerialRowIds = this.serialData.map(item => {
                return item.Id;
            });
            this.calculateSerialRowCount();
        } catch (error) {
            console.log('Error in loadSerialCollections:', error);
        } finally {
            this.isLoadingSerialTable = false;
        }
    }

    resetSerialCollections() {
        this.serialData = [];
        this.filteredSerial = [];
    }
    handleSearch(event) {
        const searchTerm = event.target.value;
        this.filterSerialCollections(searchTerm);
    }

    filterSerialCollections(searchTerm) {
        if (!searchTerm) {
            this.filteredSerial = [...this.serialData];
            this.calculateSerialRowCount();
        } else {
            const searchTermLower = searchTerm.toLowerCase();
            this.filteredSerial = this.serialData.filter(item => {
                const searchableFields = [item.Serial_Header__c, item.Serial_Sub_Header__c];
                return searchableFields.some(field =>
                    String(field || '').toLowerCase().includes(searchTermLower)
                );
            });
        }
        this.preSelectedSerialRowIds = this.serialData.filter(item => item.IsSelected).map(item => item.Id);
    }
    handleDiscountChange(event) {
        const discountVal = Number(this.refs.discount.value);
        if (discountVal > this.MAX_DISCOUNT) {
            return;
        }
        this.selectedDiscount = discountVal;
        if (this.refs.quickDiscountSelect.value) {
            this.refs.quickDiscountSelect.value = null;
        }
        this.setSerialCollectionDiscount();
    }
    handleQuickDiscountSelect(event) {
        this.selectedDiscount = Number(event.detail.value);
        if (this.refs.discount.value) {
            this.refs.discount.value = null;
        }
        this.setSerialCollectionDiscount();
    }

    setSerialCollectionDiscount() {
        if (!this.selectedDiscount || this.filteredSerial.length == 0) {
            return;
        }
        this.filteredSerial.forEach(item => {
            item.Discount = this.selectedDiscount;
        });
        this.filteredSerial = [...this.filteredSerial];
    }

    handleSerialTableSave(event) {
        const draftSerialValues = event.detail.draftValues;
        if (!this.validateSerialTable(draftSerialValues)) {
            return;
        }
        draftSerialValues.forEach(updated => {
            let record = this.filteredSerial.find(row => row.Id === updated.Id);
            if (record) {
                record.Discount = Number(updated.Discount);
            }
        });
        this.filteredSerial = [...this.filteredSerial];
        this.draftSerialValues = [];
    }

    validateSerialTable(draftSerialValues) {
        this.errors = { rows: {}, table: {} };
        const ERROR_TITLE = 'We found error(s)';

        const errorRows = draftSerialValues.reduce((errors, record) => {
            if (parseFloat(record.Discount) > this.MAX_DISCOUNT) {
                errors[record.Id] = {
                    title: ERROR_TITLE,
                    messages: 'Enter a valid discount',
                    fieldNames: { 'Discount': this.DISCOUNT_ERROR_MESSAGE }
                };
            }
            return errors;
        }, {});

        this.errors.rows = errorRows;
        const hasErrors = Object.keys(errorRows).length > 0;
        if (hasErrors) {
            this.errors.table = {
                title: ERROR_TITLE,
                messages: [this.DISCOUNT_ERROR_MESSAGE]
            };
        }
        return !hasErrors;
    }
    handleSerialRowSelection(event) {
        switch (event.detail.config.action) {
            case 'selectAllRows':
                for (let i = 0; i < event.detail.selectedRows.length; i++) {
                    this.filteredSerial.forEach(item => item.IsSelected = true);
                }
                break;
            case 'deselectAllRows':
                this.filteredSerial.forEach(item => item.IsSelected = false);
                break;
            case 'rowSelect':
                const selectedRowId = event.detail.config.value;
                let matchedSelectedRow = this.filteredSerial.find(item => item.Id === selectedRowId);
                if (matchedSelectedRow) {
                    matchedSelectedRow.IsSelected = true;
                }
                this.updateSelectionForSameSerials(matchedSelectedRow.Group_Id__c, true);
                break;
            case 'rowDeselect':
                const unselectedRowId = event.detail.config.value;
                let matchedUnselectedRow = this.filteredSerial.find(item => item.Id === unselectedRowId);
                if (matchedUnselectedRow) {
                    matchedUnselectedRow.IsSelected = false;
                }
                this.updateSelectionForSameSerials(matchedUnselectedRow.Group_Id__c, false);
                break;
            default:
                break;
        }
        this.calculateSerialRowCount();
    }

    async handleConfirmGeneratePDF() {
        const result = await LightningConfirm.open({
            message: 'Are you sure you want to generate PDF?',
            theme: 'error',
            label:'Generate PDF'
        });
        if (result) {
            this.handleGeneratePDF();
        }
    }

    async handleGeneratePDF() {
        this.isLoading = true;
        const fields = {};
        
        const selectedSerials = this.filteredSerial.filter(item => item.IsSelected);
        fields[SYSTEM_FIELD.fieldApiName] = this.selectedSystem;
        fields[DISTRICT_FIELD.fieldApiName] = this.selectedDistrict;
        fields[SALES_ORG_FIELD.fieldApiName] = this.refs.salesOrg.value;
        fields[DIST_CHANNEL_FIELD.fieldApiName] = this.refs.distChannel.value;
        fields[PDF_NAME_FIELD.fieldApiName] = this.refs.pdfName.value;
        fields[SERIAL_JSON_FIELD.fieldApiName] = JSON.stringify(selectedSerials);
        const recordInput = { apiName: LOG_OBJECT.objectApiName, fields };

        try {
            this.currentPdfLog = await createRecord(recordInput);
            this.pdfUrl = this.getPdfUrlPrefix() + this.currentPdfLog.id;
            this.pdfModalHeader = `Previewing: ${this.refs.pdfName.value}`;
            this.handlePreviewPDF();
        } catch (error) {
            console.log('Error in handleGeneratePDF:', error);
            this.showToast('Error', error.body.output.errors[0].message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getPdfUrlPrefix(){
        return this.isHvacSelected ? PDF_URL_HVAC : PDF_URL_CAS;   
    }

    handlePreviewPDF() {
        this.showPdfModal = true;
        this.isLoadingPDF = true;
    }

    navigateToPDFLogs() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ProductCatalogPDFLog__c',
                actionName: 'list'
            },
            state: {
                filterName: "All" 
            }  
        });
    }
    
    closePdfModal() {
        this.showPdfModal = false;
    }

    onPdfLoadComplete() {
        this.isLoadingPDF = false;
    }
    updateSelectionForSameSerials(groupId, isSelected){
        this.filteredSerial
            .filter(item => item.Group_Id__c === groupId)
            .forEach(item => item.IsSelected = isSelected);
    };

    mapToComboboxOptions(records, valueField, labelField) {
        return records.map(record => ({
            label: record[labelField],
            value: record[valueField]
        }));
    }
    calculateSerialRowCount() {
        this.selectedSerialRowCount = this.filteredSerial.filter(item => item.IsSelected).length;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
    get isHvacSelected() {
        return this.selectedSystem === 'Root_Collection_HVAC';
    }
    get isCasSelected() {
        return this.selectedSystem === 'Root_Collection_CAS';
    }
}