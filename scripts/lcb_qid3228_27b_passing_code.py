class Solution:
    def maximumSetSize(self, nums1: List[int], nums2: List[int]) -> int:
        n = len(nums1)
        half = n // 2
        
        # Get unique elements in each array
        set1 = set(nums1)
        set2 = set(nums2)
        
        # Count unique elements in each
        c1 = len(set1)
        c2 = len(set2)
        
        # We can keep at most 'half' distinct elements from each array
        # So effective distinct elements we can contribute from each is min(c1, half) and min(c2, half)
        keep1 = min(c1, half)
        keep2 = min(c2, half)
        
        # The maximum size of the union set is bounded by:
        # 1. The total number of distinct elements available in both arrays (union of set1 and set2)
        # 2. The sum of what we can keep from each array (keep1 + keep2)
        # But actually, the constraint is that we can only pick up to 'half' from each.
        # The best we can do is to pick as many distinct elements as possible from each,
        # but the total distinct elements in the result cannot exceed the total distinct elements available.
        # Also, the total distinct elements cannot exceed keep1 + keep2 (since we can only keep that many from each).
        # However, if there is overlap, we might not be able to reach keep1 + keep2 distinct elements.
        # Actually, the answer is simply min(len(set1 | set2), keep1 + keep2)
        
        total_distinct = len(set1 | set2)
        return min(total_distinct, keep1 + keep2)