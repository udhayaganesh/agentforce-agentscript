public with sharing class OfferController {

    // Output wrapper returned to Agentforce / Flow
    public class OfferOutput {
        @InvocableVariable(label='Offer ID' description='Unique offer identifier')
        public String id;

        @InvocableVariable(label='Offer Title' description='Display name of the offer')
        public String title;

        @InvocableVariable(label='Description' description='Summary of the promotion terms')
        public String description;

        @InvocableVariable(label='Offer Type' description='Type of promotion (e.g., Spend Threshold, Frequency)')
        public String offerType;

        @InvocableVariable(label='Discount Amount ($)' description='Fixed dollar discount amount')
        public Decimal discountAmount;

        @InvocableVariable(label='Discount Percentage (%)' description='Percentage discount amount')
        public Decimal discountPercentage;

        public OfferOutput(String id, String title, String description, String offerType, Decimal discountAmount, Decimal discountPercentage) {
            this.id = id;
            this.title = title;
            this.description = description;
            this.offerType = offerType;
            this.discountAmount = discountAmount;
            this.discountPercentage = discountPercentage;
        }
    }

    // Input parameter class (required for Invocable methods, even if empty)
    public class OfferRequest {
        @InvocableVariable(label='Category Filter' description='Optional filter by offer type (e.g., Spend Threshold)')
        public String categoryFilter;
    }

    /**
     * Invocable method exposed to Agent Scripts, Flow, and Agentforce Actions.
     */
    @InvocableMethod(
        label='Get Available Offers'
        description='Returns active promotions like Spend $100 get $10 or Buy 3 get 50% off for customer scripts.'
        category='Promotions'
    )
    public static List<List<OfferOutput>> getOffers(List<OfferRequest> requests) {
        List<OfferOutput> offerList = new List<OfferOutput>();

        offerList.add(new OfferOutput(
            'OFFER-001',
            'Spend & Save',
            'Spend $100 or more in a single transaction and get $10 off your total bill.',
            'Spend Threshold',
            10.00,
            null
        ));

        offerList.add(new OfferOutput(
            'OFFER-002',
            'Loyalty Frequency Reward',
            'Make 3 purchases this month to get 50% off your next order.',
            'Frequency Reward',
            null,
            50.00
        ));

        offerList.add(new OfferOutput(
            'OFFER-003',
            'Buy 2 Get 1 Free',
            'Add 3 eligible items to your cart and the lowest-priced item is free.',
            'Bundle Discount',
            null,
            100.00
        ));

        // Invocable methods return a List of Lists to support bulkified Flow/Agent execution
        List<List<OfferOutput>> results = new List<List<OfferOutput>>();
        results.add(offerList);
        return results;
    }
}