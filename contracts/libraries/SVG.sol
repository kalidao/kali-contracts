// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Core SVG utility library which helps us construct
/// onchain SVGs with a simple, web-like API
/// @author Modified from (https://github.com/w1nt3r-eth/hot-chain-svg)
/// License-Identifier: MIT
library SVG {
    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    string internal constant NULL = '';

    /// -----------------------------------------------------------------------
    /// Elements
    /// -----------------------------------------------------------------------

    function text(string memory props, string memory children)
        internal
        pure
        returns (string memory)
    {
        return el('text', props, children);
    }

    function rect(string memory props, string memory children)
        internal
        pure
        returns (string memory)
    {
        return el('rect', props, children);
    }

    function image(string memory href, string memory props)
        internal
        pure
        returns (string memory)
    {
        return
            el('image', string.concat(prop('href', href), ' ', props), NULL);
    }

    function cdata(string memory content)
        internal
        pure
        returns (string memory)
    {
        return string.concat('<![CDATA[', content, ']]>');
    }

    /// -----------------------------------------------------------------------
    /// Generics
    /// -----------------------------------------------------------------------

    /// @dev a generic element, can be used to construct any SVG (or HTML) element
    function el(
        string memory tag,
        string memory props,
        string memory children
    ) internal pure returns (string memory) {
        return
            string.concat(
                '<',
                tag,
                ' ',
                props,
                '>',
                children,
                '</',
                tag,
                '>'
            );
    }

    /// @dev an SVG attribute
    function prop(string memory key, string memory val)
        internal
        pure
        returns (string memory)
    {
        return string.concat(key, '=', '"', val, '" ');
    }

    /// @dev converts an unsigned integer to a string
    function uint2str(uint256 i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (i == 0) {
            return '0';
        }
        uint256 j = i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(i - (i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            i /= 10;
        }
        return string(bstr);
    }
}
