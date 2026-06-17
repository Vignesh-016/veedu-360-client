import { IconChevronLeft, IconChevronRight } from '@tabler/icons-react';

interface PaginationControlsProps {
    currentPage: number;
    totalPages: number;
    onPageChange: (page: number) => void;
    itemsPerPage: number;
    totalItems: number;
}

function PaginationControls({
    currentPage,
    totalPages,
    onPageChange,
    itemsPerPage,
    totalItems
}: PaginationControlsProps) {
    if (totalPages <= 1) {
        return null;
    }

    const handlePrevious = () => {
        if (currentPage > 1) {
            onPageChange(currentPage - 1);
        }
    };

    const handleNext = () => {
        if (currentPage < totalPages) {
            onPageChange(currentPage + 1);
        }
    };

    const getPageNumbers = () => {
        const pages = [];
        const maxPagesToShow = 5;
        const halfMaxPages = Math.floor(maxPagesToShow / 2);

        let startPage = Math.max(1, currentPage - halfMaxPages);
        let endPage = Math.min(totalPages, currentPage + halfMaxPages);

        // Adjust if we're near the beginning
        if (currentPage - halfMaxPages < 1) {
            endPage = Math.min(totalPages, maxPagesToShow);
        }

        // Adjust if we're near the end
        if (currentPage + halfMaxPages > totalPages) {
            startPage = Math.max(1, totalPages - maxPagesToShow + 1);
        }

        // Add first page and ellipsis if needed
        if (startPage > 1) {
            pages.push(1);
            if (startPage > 2) {
                pages.push('...');
            }
        }

        // Add page numbers in the calculated range
        for (let i = startPage; i <= endPage; i++) {
            pages.push(i);
        }

        // Add last page and ellipsis if needed
        if (endPage < totalPages) {
            if (endPage < totalPages - 1) {
                pages.push('...');
            }
            pages.push(totalPages);
        }

        return pages;
    };

    const pageNumbers = getPageNumbers();
    const firstItemIndex = Math.min((currentPage - 1) * itemsPerPage + 1, totalItems);
    const lastItemIndex = Math.min(currentPage * itemsPerPage, totalItems);

    return (
        <div className="flex flex-col sm:flex-row items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6 mt-8 rounded-b-lg">
            {/* Info Text (Mobile Hidden) */}
            <div className="hidden sm:block">
                <p className="text-sm text-gray-700">
                    Showing <span className="font-medium">{firstItemIndex}</span> to <span className="font-medium">{lastItemIndex}</span> of{' '}
                    <span className="font-medium">{totalItems}</span> results
                </p>
            </div>

            {/* Pagination Controls */}
            <div className="flex flex-1 justify-between sm:justify-end items-center gap-1">
                {/* Previous Button */}
                <button
                    onClick={handlePrevious}
                    disabled={currentPage === 1}
                    className="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <IconChevronLeft size={16} className="mr-1" />
                    Previous
                </button>

                {/* Page Numbers (Desktop/Tablet) */}
                <nav className="hidden md:flex items-center space-x-1 mx-2" aria-label="Pagination">
                    {pageNumbers.map((page, index) => (
                        <span key={index}>
                            {page === '...' ? (
                                <span className="px-3 py-1.5 text-sm font-medium text-gray-500">...</span>
                            ) : (
                                <button
                                    onClick={() => onPageChange(page as number)}
                                    className={`px-3 py-1.5 text-sm font-medium rounded-md ${currentPage === page
                                        ? 'bg-gray-600 text-white border border-gray-600 z-10'
                                        : 'text-gray-500 hover:bg-gray-100 border border-transparent'
                                        }`}
                                    aria-current={currentPage === page ? 'page' : undefined}
                                >
                                    {page}
                                </button>
                            )}
                        </span>
                    ))}
                </nav>
                {/* Current Page Info (Mobile) */}
                <div className="md:hidden text-sm text-gray-600">
                    Page {currentPage} of {totalPages}
                </div>

                {/* Next Button */}
                <button
                    onClick={handleNext}
                    disabled={currentPage === totalPages}
                    className="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    Next
                    <IconChevronRight size={16} className="ml-1" />
                </button>
            </div>
        </div>
    );
}

export default PaginationControls;