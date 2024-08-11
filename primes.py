import csv
from collections import Counter

def analyze_primes():
    # Read the CSV file
    class PrimeRow:
        def __init__(self, diff_bits, prime1, prime2):
            self.diff_bits = int(diff_bits)
            self.prime1 = int(prime1)
            self.prime2 = int(prime2)

    with open('output_20240801_115631.csv', 'r') as file:  # Replace with your actual filename
        csv_reader = csv.DictReader(file)
        
        
        # Store each row in its own object
        rows = []
        for row in csv_reader:
            rows.append(PrimeRow(row['Diff Bits'], row['Prime1'], row['Prime2']))
        
        # Count values for Prime2 column
        prime2_counter = Counter(row.prime2 for row in rows)
        
        # Get the top 25 most common numbers for Prime2
        top_25_prime2 = prime2_counter.most_common(25)
        
        print("Top 25 most common numbers in Prime2:")
        for number, count in top_25_prime2:
            print(f"{number}: {count}")
        
        # Count of unique numbers in Prime2
        unique_prime2 = len(prime2_counter)
        print(f"\nNumber of unique values in Prime2: {unique_prime2}")

        # Calculate percentiles for unique counts in Prime2
        sorted_counts = sorted(prime2_counter.values())
        total_counts = len(sorted_counts)
        
        print("\nPercentiles for unique counts in Prime2:")
        for i in range(10, 101, 10):
            index = (i / 100) * (total_counts - 1)
            if index.is_integer():
                percentile = sorted_counts[int(index)]
            else:
                lower = sorted_counts[int(index)]
                upper = sorted_counts[int(index) + 1]
                percentile = lower + (upper - lower) * (index - int(index))
            print(f"{i}th percentile: {percentile:.2f}")

        # Sort rows by diff_bits in descending order
        sorted_rows = sorted(rows, key=lambda x: x.diff_bits, reverse=True)
        
        # Get the top 25 rows with highest diff_bits
        top_25_diff_bits = sorted_rows[:25]
        
        print("\nTop 25 primes with highest diff bits:")
        print("Diff Bits | Prime1 | Prime2")
        print("-" * 30)
        for row in top_25_diff_bits:
            print(f"{row.diff_bits:9d} | {row.prime1:6d} | {row.prime2:6d}")

        # Save out the top 10th percentile of Prime2 into a tab-separated txt file
        percentile_90th = sorted_counts[int(0.90 * (total_counts - 1))]
        top_10th_percentile = [str(num) for num, count in prime2_counter.items() if count >= percentile_90th]
        
        with open('top-percentile-primes.txt', 'w') as outfile:
            outfile.write('\t'.join(top_10th_percentile))
        print("\nTop 10th percentile of Prime2 saved to 'top-percentile-primes.txt'")

if __name__ == "__main__":
    analyze_primes()
